import 'dart:convert';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';

import '../../core/pairing.dart';
import '../../models/agent_message.dart';
import '../../providers/agent_state_provider.dart';
import '../../providers/speech_provider.dart';
import '../../providers/terminal_session_provider.dart';
import '../../relay/session.dart';
import '../adaptive.dart';

class TerminalScreen extends ConsumerStatefulWidget {
  final PairingUri pairing;

  const TerminalScreen({super.key, required this.pairing});

  @override
  ConsumerState<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends ConsumerState<TerminalScreen>
    with WidgetsBindingObserver {
  // Controllers stay in State (not in providers) because they are
  // tied to widget lifecycle and don't represent business state.
  final TextEditingController _promptController = TextEditingController();
  final ScrollController _agentScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Kick off the connection.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(terminalSessionProvider(widget.pairing).notifier).connect();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _promptController.dispose();
    _agentScrollController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // App lifecycle
  // ---------------------------------------------------------------------------

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final notifier = ref.read(terminalSessionProvider(widget.pairing).notifier);
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        notifier.pauseHeartbeat();
      case AppLifecycleState.resumed:
        notifier.resumeOrReconnect();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  // ---------------------------------------------------------------------------
  // Back button / disconnect
  // ---------------------------------------------------------------------------

  Future<bool> _onBackPressed() async {
    final sessionState =
        ref.read(terminalSessionProvider(widget.pairing)).sessionState;
    if (sessionState == SessionState.disconnected ||
        sessionState == SessionState.error) {
      return true;
    }

    final shouldDisconnect = await showAdaptiveConfirmDialog(
      context: context,
      title: 'Disconnect?',
      content: 'This will end your terminal session.',
      confirmLabel: 'Disconnect',
      isDestructive: true,
    );

    if (shouldDisconnect) {
      await ref
          .read(terminalSessionProvider(widget.pairing).notifier)
          .disconnect();
      return true;
    }
    return false;
  }

  void _close() async {
    if (await _onBackPressed()) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  // ---------------------------------------------------------------------------
  // Send control characters / special keys
  // ---------------------------------------------------------------------------

  void _sendBytes(List<int> bytes) {
    HapticFeedback.lightImpact();
    ref
        .read(terminalSessionProvider(widget.pairing).notifier)
        .sendInput(Uint8List.fromList(bytes));
  }

  void _sendCtrl(String char) {
    final code = char.toUpperCase().codeUnitAt(0) - 0x40;
    if (code >= 1 && code <= 26) {
      _sendBytes([code]);
    }
  }

  void _pasteClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      ref
          .read(terminalSessionProvider(widget.pairing).notifier)
          .sendInput(Uint8List.fromList(utf8.encode(data.text!)));
      HapticFeedback.lightImpact();
    }
  }

  // ---------------------------------------------------------------------------
  // Toast handling
  // ---------------------------------------------------------------------------

  void _checkToast() {
    final toast = ref
        .read(terminalSessionProvider(widget.pairing).notifier)
        .consumeToast();
    if (toast != null && mounted) {
      showAdaptiveToast(context, toast);
    }
  }

  // ---------------------------------------------------------------------------
  // Scroll agent view to bottom
  // ---------------------------------------------------------------------------

  void _scrollAgentToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_agentScrollController.hasClients) {
        _agentScrollController.animateTo(
          _agentScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Status bar
  // ---------------------------------------------------------------------------

  Widget _buildStatusBar() {
    final ts = ref.watch(terminalSessionProvider(widget.pairing));
    final (icon, label, color) = switch (ts.sessionState) {
      SessionState.disconnected     => (Icons.link_off, 'Disconnected', Colors.grey),
      SessionState.connecting       => (Icons.sync, 'Connecting...', Colors.orange),
      SessionState.waitingForPeer   => (Icons.hourglass_empty, 'Waiting for host...', Colors.orange),
      SessionState.handshaking      => (Icons.handshake, 'Key exchange...', Colors.amber),
      SessionState.awaitingConfirm  => (Icons.handshake, 'Verifying...', Colors.amber),
      SessionState.connected        => (Icons.lock, 'Connected (E2E encrypted)', Colors.green),
      SessionState.reconnecting     => (Icons.sync, 'Reconnecting...', Colors.orange),
      SessionState.error            => (Icons.error, ts.error ?? 'Error', Colors.red),
    };

    final showReconnect = ts.sessionState == SessionState.error ||
        ts.sessionState == SessionState.disconnected;

    if (isApplePlatform) {
      return GlassContainer(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        borderRadius: 0,
        color: const Color(0x801C1C1E),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label,
                  style: TextStyle(color: color, fontSize: 12),
                  overflow: TextOverflow.ellipsis),
            ),
            if (ts.toolName != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(ts.toolName!,
                    style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ),
            if (showReconnect)
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                onPressed: () => ref
                    .read(terminalSessionProvider(widget.pairing).notifier)
                    .connect(),
                child: Icon(CupertinoIcons.refresh,
                    size: 16, color: Colors.grey[400]),
              ),
          ],
        ),
      );
    }

    return Container(
      color: Colors.grey[900],
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: TextStyle(color: color, fontSize: 12),
                overflow: TextOverflow.ellipsis),
          ),
          if (ts.toolName != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(ts.toolName!,
                  style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            ),
          if (showReconnect)
            GestureDetector(
              onTap: () => ref
                  .read(terminalSessionProvider(widget.pairing).notifier)
                  .connect(),
              child: Icon(Icons.refresh, size: 16, color: Colors.grey[400]),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Terminal toolbar
  // ---------------------------------------------------------------------------

  void _showTerminalActions() {
    if (isApplePlatform) {
      _showCupertinoTerminalActions();
    } else {
      _showMaterialTerminalActions();
    }
  }

  void _showCupertinoTerminalActions() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Terminal Actions'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () { Navigator.pop(ctx); _sendCtrl('C'); },
            child: const Text('Interrupt (Ctrl+C)'),
          ),
          CupertinoActionSheetAction(
            onPressed: () { Navigator.pop(ctx); _sendCtrl('D'); },
            child: const Text('EOF (Ctrl+D)'),
          ),
          CupertinoActionSheetAction(
            onPressed: () { Navigator.pop(ctx); _sendCtrl('Z'); },
            child: const Text('Suspend (Ctrl+Z)'),
          ),
          CupertinoActionSheetAction(
            onPressed: () { Navigator.pop(ctx); _sendCtrl('L'); },
            child: const Text('Clear (Ctrl+L)'),
          ),
          CupertinoActionSheetAction(
            onPressed: () { Navigator.pop(ctx); _sendCtrl('R'); },
            child: const Text('Search (Ctrl+R)'),
          ),
          CupertinoActionSheetAction(
            onPressed: () { Navigator.pop(ctx); _sendBytes([0x1b]); },
            child: const Text('Escape'),
          ),
          CupertinoActionSheetAction(
            onPressed: () { Navigator.pop(ctx); _pasteClipboard(); },
            child: const Text('Paste Clipboard'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showMaterialTerminalActions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[700],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                _actionSection('Control', [
                  _actionTile(Icons.stop_circle_outlined, 'Interrupt', 'Ctrl+C', () => _sendCtrl('C')),
                  _actionTile(Icons.logout, 'EOF', 'Ctrl+D', () => _sendCtrl('D')),
                  _actionTile(Icons.pause_circle_outline, 'Suspend', 'Ctrl+Z', () => _sendCtrl('Z')),
                  _actionTile(Icons.refresh, 'Clear', 'Ctrl+L', () => _sendCtrl('L')),
                ]),
                const SizedBox(height: 12),
                _actionSection('Navigate', [
                  _actionTile(Icons.arrow_upward, 'Previous', 'Up', () => _sendBytes([0x1b, 0x5b, 0x41])),
                  _actionTile(Icons.arrow_downward, 'Next', 'Down', () => _sendBytes([0x1b, 0x5b, 0x42])),
                  _actionTile(Icons.keyboard_tab, 'Tab', 'Tab', () => _sendBytes([0x09])),
                  _actionTile(Icons.first_page, 'Escape', 'Esc', () => _sendBytes([0x1b])),
                ]),
                const SizedBox(height: 12),
                _actionSection('Edit', [
                  _actionTile(Icons.content_paste, 'Paste', '', _pasteClipboard),
                  _actionTile(Icons.search, 'Search', 'Ctrl+R', () => _sendCtrl('R')),
                ]),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _actionSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title,
              style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        ),
        Wrap(spacing: 8, runSpacing: 8, children: children),
      ],
    );
  }

  Widget _actionTile(IconData icon, String label, String shortcut, VoidCallback onTap) {
    return Material(
      color: Colors.grey[800],
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () { onTap(); Navigator.pop(context); },
        child: Container(
          width: 80,
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 12), textAlign: TextAlign.center),
              if (shortcut.isNotEmpty)
                Text(shortcut, style: TextStyle(color: Colors.grey[500], fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Listening overlay
  // ---------------------------------------------------------------------------

  Widget _buildListeningOverlay() {
    final speech = ref.watch(speechProvider);
    return Positioned(
      bottom: 80 + MediaQuery.of(context).padding.bottom,
      left: 24,
      right: 24,
      child: GlassContainer(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const _PulsingDot(),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                speech.liveTranscript.isEmpty ? 'Listening...' : speech.liveTranscript,
                style: TextStyle(
                  color: speech.liveTranscript.isEmpty ? Colors.grey[400] : Colors.white,
                  fontSize: 14,
                  fontStyle: speech.liveTranscript.isEmpty ? FontStyle.italic : FontStyle.normal,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Mic button
  // ---------------------------------------------------------------------------

  Widget _buildMicButton() {
    final speech = ref.watch(speechProvider);
    if (isApplePlatform) {
      return CupertinoButton(
        padding: const EdgeInsets.all(14),
        color: speech.listening
            ? CupertinoColors.destructiveRed
            : const Color(0xCC3A3A3C),
        borderRadius: BorderRadius.circular(28),
        onPressed: () {
          if (speech.listening) {
            ref.read(speechProvider.notifier).stopListening();
          } else {
            HapticFeedback.heavyImpact();
            ref.read(speechProvider.notifier).startListening();
          }
        },
        child: Icon(
          speech.listening ? CupertinoIcons.mic_fill : CupertinoIcons.mic,
          color: speech.listening ? CupertinoColors.white : Colors.grey[400],
          size: 22,
        ),
      );
    }
    return FloatingActionButton(
      backgroundColor: speech.listening ? Colors.redAccent : Colors.grey[800],
      onPressed: () {
        if (speech.listening) {
          ref.read(speechProvider.notifier).stopListening();
        } else {
          HapticFeedback.heavyImpact();
          ref.read(speechProvider.notifier).startListening();
        }
      },
      tooltip: speech.listening ? 'Tap to stop' : 'Tap to speak',
      child: Icon(
        speech.listening ? Icons.mic : Icons.mic_none,
        color: speech.listening ? Colors.white : Colors.grey[400],
        size: 24,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final ts = ref.watch(terminalSessionProvider(widget.pairing));
    final agent = ref.watch(agentStateProvider);
    final speech = ref.watch(speechProvider);

    // Check for pending toast messages.
    _checkToast();

    // Fill prompt bar with completed transcript from speech provider.
    if (speech.completedTranscript != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _promptController.text = speech.completedTranscript!;
        _promptController.selection = TextSelection.fromPosition(
          TextPosition(offset: _promptController.text.length),
        );
        ref.read(speechProvider.notifier).clearCompletedTranscript();
        HapticFeedback.mediumImpact();
      });
    }

    final showMicFab = !agent.showStructuredView &&
        speech.available &&
        ts.sessionState == SessionState.connected;

    final terminal = ref.read(terminalSessionProvider(widget.pairing).notifier).terminal;

    final bodyContent = Stack(
      children: [
        Column(
          children: [
            _buildStatusBar(),
            Expanded(
              child: agent.showStructuredView
                  ? _buildStructuredView()
                  : TerminalView(terminal, autofocus: true),
            ),
          ],
        ),
        if (speech.listening && !agent.showStructuredView) _buildListeningOverlay(),
        if (showMicFab)
          Positioned(
            right: 16,
            bottom: (agent.showStructuredView ? 80 : 24) +
                MediaQuery.of(context).padding.bottom,
            child: _buildMicButton(),
          ),
      ],
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _onBackPressed()) navigator.pop();
      },
      child: isApplePlatform
          ? _buildCupertinoShell(bodyContent, ts, agent)
          : _buildMaterialShell(bodyContent, ts, agent),
    );
  }

  Widget _buildMaterialShell(Widget body, TerminalSessionState ts, AgentState agent) {
    return Scaffold(
      resizeToAvoidBottomInset: agent.showStructuredView,
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Terminal'),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _close),
        actions: [
          if (ts.sessionState == SessionState.error ||
              ts.sessionState == SessionState.disconnected)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Reconnect',
              onPressed: () => ref
                  .read(terminalSessionProvider(widget.pairing).notifier)
                  .connect(),
            ),
          if (agent.hasStructuredEvents)
            IconButton(
              icon: Icon(agent.showStructuredView ? Icons.terminal : Icons.auto_awesome),
              tooltip: agent.showStructuredView ? 'Terminal view' : 'Structured view',
              onPressed: () => ref.read(agentStateProvider.notifier).toggleView(),
            ),
          if (!agent.showStructuredView)
            IconButton(
              icon: const Icon(Icons.keyboard_command_key),
              tooltip: 'Terminal actions',
              onPressed: _showTerminalActions,
            ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildCupertinoShell(Widget body, TerminalSessionState ts, AgentState agent) {
    return CupertinoPageScaffold(
      resizeToAvoidBottomInset: agent.showStructuredView,
      backgroundColor: CupertinoColors.black,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: const Color(0xB01C1C1E),
        middle: const Text('Terminal', style: TextStyle(color: CupertinoColors.white)),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: _close,
          child: const Icon(CupertinoIcons.back, color: CupertinoColors.systemTeal, size: 22),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (ts.sessionState == SessionState.error ||
                ts.sessionState == SessionState.disconnected)
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: Size.zero,
                onPressed: () => ref
                    .read(terminalSessionProvider(widget.pairing).notifier)
                    .connect(),
                child: const Icon(CupertinoIcons.refresh, color: CupertinoColors.white, size: 20),
              ),
            if (agent.hasStructuredEvents)
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: Size.zero,
                onPressed: () => ref.read(agentStateProvider.notifier).toggleView(),
                child: Icon(
                  agent.showStructuredView ? Icons.terminal : CupertinoIcons.sparkles,
                  color: CupertinoColors.white, size: 20,
                ),
              ),
            if (!agent.showStructuredView)
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: Size.zero,
                onPressed: _showTerminalActions,
                child: const Icon(CupertinoIcons.command, color: CupertinoColors.white, size: 20),
              ),
          ],
        ),
      ),
      child: SafeArea(top: false, child: body),
    );
  }

  // ---------------------------------------------------------------------------
  // Structured agent view
  // ---------------------------------------------------------------------------

  Widget _buildCostTicker() {
    final agent = ref.watch(agentStateProvider);
    if (agent.costUsd == 0.0 && agent.inputTokens == 0) return const SizedBox.shrink();

    String formatTokens(int tokens) {
      if (tokens >= 1000000) return '${(tokens / 1000000).toStringAsFixed(1)}M';
      if (tokens >= 1000) return '${(tokens / 1000).toStringAsFixed(1)}K';
      return tokens.toString();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.08),
        border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.15))),
      ),
      child: Row(
        children: [
          Icon(Icons.toll, color: Colors.grey[600], size: 14),
          const SizedBox(width: 6),
          Text('\$${agent.costUsd.toStringAsFixed(4)}',
              style: TextStyle(color: Colors.grey[400], fontSize: 12, fontFamily: 'monospace')),
          const SizedBox(width: 12),
          Icon(Icons.arrow_downward, color: Colors.grey[600], size: 12),
          const SizedBox(width: 3),
          Text(formatTokens(agent.inputTokens),
              style: TextStyle(color: Colors.grey[500], fontSize: 11)),
          const SizedBox(width: 8),
          Icon(Icons.arrow_upward, color: Colors.grey[600], size: 12),
          const SizedBox(width: 3),
          Text(formatTokens(agent.outputTokens),
              style: TextStyle(color: Colors.grey[500], fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildTodoList() {
    final agent = ref.watch(agentStateProvider);
    if (agent.todos.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.only(left: 12, right: 12, top: 8),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.checklist, color: Colors.blueGrey[300], size: 14),
              const SizedBox(width: 6),
              Text('Tasks',
                  style: TextStyle(color: Colors.blueGrey[200], fontSize: 12, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('${agent.todos.where((t) => t.status == "completed").length}/${agent.todos.length}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 11)),
            ],
          ),
          const SizedBox(height: 6),
          ...agent.todos.map((todo) {
            final isCompleted = todo.status == 'completed';
            final isCancelled = todo.status == 'cancelled';
            final isInProgress = todo.status == 'in_progress';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isCompleted ? Icons.check_circle : isCancelled ? Icons.cancel
                        : isInProgress ? Icons.play_circle_filled : Icons.radio_button_unchecked,
                    color: isCompleted ? Colors.green[400] : isCancelled ? Colors.grey[600]
                        : isInProgress ? Colors.blue[400] : Colors.grey[600],
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  if (todo.priority == 'high')
                    Container(
                      width: 6, height: 6,
                      margin: const EdgeInsets.only(top: 4, right: 4),
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.redAccent),
                    ),
                  Expanded(
                    child: Text(todo.content,
                        style: TextStyle(
                          color: isCompleted || isCancelled ? Colors.grey[600] : Colors.grey[300],
                          fontSize: 12,
                          decoration: isCancelled ? TextDecoration.lineThrough : null,
                        )),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStructuredView() {
    final agent = ref.watch(agentStateProvider);

    // Auto-scroll when messages change.
    if (agent.messages.isNotEmpty) _scrollAgentToBottom();

    return Column(
      children: [
        _buildCostTicker(),
        _buildTodoList(),
        Expanded(
          child: agent.messages.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome, color: Colors.cyan[300], size: 40),
                        const SizedBox(height: 16),
                        Text(
                          'Connected to ${ref.read(terminalSessionProvider(widget.pairing)).toolName ?? "agent"}',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Type a prompt below or use the desktop terminal.\nActivity will appear here as the agent works.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[500], fontSize: 13, height: 1.5),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.info_outline, color: Colors.amber[300], size: 14),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'Both devices can type at the same time. Avoid sending while the desktop is typing.',
                                  style: TextStyle(color: Colors.amber[300], fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _agentScrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: agent.messages.length,
                  itemBuilder: (context, index) => _buildAgentMessageCard(agent.messages[index]),
                ),
        ),
        _buildPromptBar(),
      ],
    );
  }

  Widget _buildAgentMessageCard(AgentMessage msg) {
    return switch (msg.type) {
      AgentMessageType.system => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.blueGrey.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
          child: Text(msg.text, style: TextStyle(color: Colors.grey[400], fontSize: 12, fontFamily: 'monospace')),
        ),
      ),
      AgentMessageType.text => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: SelectableText(msg.text, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5)),
      ),
      AgentMessageType.thinking => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.purple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.psychology, color: Colors.purple[300], size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(msg.text, style: TextStyle(color: Colors.purple[200], fontSize: 13, fontStyle: FontStyle.italic))),
          ]),
        ),
      ),
      AgentMessageType.toolCall => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.cyan.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.cyan.withValues(alpha: 0.3)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.build, color: Colors.cyan[300], size: 16),
              const SizedBox(width: 6),
              Text(msg.text, style: TextStyle(color: Colors.cyan[200], fontWeight: FontWeight.bold, fontSize: 13)),
            ]),
            if (msg.toolInput != null && msg.toolInput!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(msg.toolInput!.length > 200 ? '${msg.toolInput!.substring(0, 200)}...' : msg.toolInput!,
                  style: TextStyle(color: Colors.grey[500], fontSize: 11, fontFamily: 'monospace')),
            ],
          ]),
        ),
      ),
      AgentMessageType.toolResult => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
          child: Text(msg.text.length > 300 ? '${msg.text.substring(0, 300)}...' : msg.text,
              style: TextStyle(color: Colors.grey[500], fontSize: 11, fontFamily: 'monospace'), maxLines: 10, overflow: TextOverflow.ellipsis),
        ),
      ),
      AgentMessageType.toolError => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 14),
            const SizedBox(width: 6),
            Expanded(child: Text(msg.text, style: const TextStyle(color: Colors.redAccent, fontSize: 12), maxLines: 5, overflow: TextOverflow.ellipsis)),
          ]),
        ),
      ),
      AgentMessageType.turnMarker => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Expanded(child: Divider(color: Colors.grey[700])),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(msg.text, style: TextStyle(color: Colors.grey[600], fontSize: 11))),
          Expanded(child: Divider(color: Colors.grey[700])),
        ]),
      ),
      AgentMessageType.permissionRequest => _buildPermissionCard(msg),
    };
  }

  Widget _buildPermissionCard(AgentMessage msg) {
    final agent = ref.watch(agentStateProvider);
    final permId = msg.toolId ?? '';
    final resolved = agent.pendingPermissions[permId];
    final isPending = resolved == null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: GlassContainer(
        padding: const EdgeInsets.all(12),
        color: isPending ? Colors.amber.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.08),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(isPending ? Icons.security : Icons.check_circle_outline,
                  color: isPending ? Colors.amber[300] : Colors.grey[500], size: 16),
              const SizedBox(width: 8),
              Text(msg.toolName ?? 'Tool',
                  style: TextStyle(color: isPending ? Colors.amber[200] : Colors.grey[500], fontWeight: FontWeight.bold, fontSize: 13)),
              if (!isPending) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: resolved == 'allow' ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(resolved == 'allow' ? 'Allowed' : 'Denied',
                      style: TextStyle(color: resolved == 'allow' ? Colors.green[300] : Colors.red[300], fontSize: 10, fontWeight: FontWeight.w500)),
                ),
              ],
            ]),
            const SizedBox(height: 6),
            Text(msg.text, style: TextStyle(color: isPending ? Colors.white : Colors.grey[500], fontSize: 13)),
            if (msg.toolInput != null && msg.toolInput!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(msg.toolInput!.length > 150 ? '${msg.toolInput!.substring(0, 150)}...' : msg.toolInput!,
                  style: TextStyle(color: Colors.grey[600], fontSize: 11, fontFamily: 'monospace')),
            ],
            if (isPending) ...[
              const SizedBox(height: 10),
              _buildPermissionButtons(permId),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionButtons(String permId) {
    final sessionNotifier = ref.read(terminalSessionProvider(widget.pairing).notifier);
    if (isApplePlatform) {
      return Row(children: [
        Expanded(
          child: CupertinoButton(
            padding: const EdgeInsets.symmetric(vertical: 8),
            color: Colors.red.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
            onPressed: () {
              HapticFeedback.mediumImpact();
              sessionNotifier.sendDenyToolUse(permId);
              ref.read(agentStateProvider.notifier).resolvePermission(permId, 'deny');
            },
            child: Text('Deny', style: TextStyle(color: Colors.red[300], fontSize: 13)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: CupertinoButton(
            padding: const EdgeInsets.symmetric(vertical: 8),
            color: Colors.green.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
            onPressed: () {
              HapticFeedback.mediumImpact();
              sessionNotifier.sendApproveToolUse(permId);
              ref.read(agentStateProvider.notifier).resolvePermission(permId, 'allow');
            },
            child: Text('Allow', style: TextStyle(color: Colors.green[200], fontSize: 13)),
          ),
        ),
      ]);
    }
    return Row(children: [
      Expanded(
        child: SizedBox(
          height: 36,
          child: OutlinedButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              sessionNotifier.sendDenyToolUse(permId);
              ref.read(agentStateProvider.notifier).resolvePermission(permId, 'deny');
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red[300],
              side: BorderSide(color: Colors.red.withValues(alpha: 0.4)),
              padding: EdgeInsets.zero,
            ),
            child: const Text('Deny', style: TextStyle(fontSize: 13)),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: SizedBox(
          height: 36,
          child: ElevatedButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              sessionNotifier.sendApproveToolUse(permId);
              ref.read(agentStateProvider.notifier).resolvePermission(permId, 'allow');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.withValues(alpha: 0.3),
              foregroundColor: Colors.green[200],
              padding: EdgeInsets.zero,
            ),
            child: const Text('Allow', style: TextStyle(fontSize: 13)),
          ),
        ),
      ),
    ]);
  }

  void _sendPrompt() {
    final text = _promptController.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    ref.read(terminalSessionProvider(widget.pairing).notifier).sendAgentPrompt(text);
    _promptController.clear();
  }

  Widget _buildPromptBar() {
    final agent = ref.watch(agentStateProvider);
    final speech = ref.watch(speechProvider);
    final hasText = _promptController.text.trim().isNotEmpty;

    if (isApplePlatform) return _buildCupertinoPromptBar(hasText, agent, speech);
    return _buildMaterialPromptBar(hasText, agent, speech);
  }

  Widget _buildCupertinoPromptBar(bool hasText, AgentState agent, SpeechState speech) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xCC1C1C1E),
            border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
          ),
          child: SafeArea(
            top: false,
            child: Row(children: [
              Expanded(
                child: CupertinoTextField(
                  controller: _promptController,
                  enabled: !agent.agentBusy,
                  style: const TextStyle(color: CupertinoColors.white, fontSize: 14),
                  placeholder: speech.listening ? 'Listening...' : agent.agentBusy ? 'Agent is working...' : 'Send a prompt...',
                  placeholderStyle: TextStyle(color: speech.listening ? CupertinoColors.destructiveRed : Colors.grey[600]),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(color: const Color(0xFF2C2C2E), borderRadius: BorderRadius.circular(20)),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendPrompt(),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 36, height: 36,
                child: agent.agentBusy
                    ? const Center(child: CupertinoActivityIndicator())
                    : CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        color: hasText ? CupertinoColors.systemTeal
                            : (speech.listening ? CupertinoColors.destructiveRed : const Color(0xFF3A3A3C)),
                        borderRadius: BorderRadius.circular(18),
                        onPressed: () {
                          if (hasText) { _sendPrompt(); }
                          else if (speech.listening) { ref.read(speechProvider.notifier).stopListening(); }
                          else if (speech.available) { HapticFeedback.heavyImpact(); ref.read(speechProvider.notifier).startListening(); }
                        },
                        child: Icon(
                          hasText ? CupertinoIcons.arrow_up : speech.listening ? CupertinoIcons.stop_fill : CupertinoIcons.mic,
                          color: CupertinoColors.white, size: 18,
                        ),
                      ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildMaterialPromptBar(bool hasText, AgentState agent, SpeechState speech) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: Border(top: BorderSide(color: Colors.grey[800]!)),
      ),
      child: SafeArea(
        top: false,
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _promptController,
              enabled: !agent.agentBusy,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: speech.listening ? 'Listening...' : agent.agentBusy ? 'Agent is working...' : 'Send a prompt...',
                hintStyle: TextStyle(color: speech.listening ? Colors.redAccent : Colors.grey[600]),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: Colors.grey[700]!)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: Colors.grey[700]!)),
                disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: Colors.grey[800]!)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                isDense: true,
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendPrompt(),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 40, height: 40,
            child: agent.agentBusy
                ? Container(
                    decoration: BoxDecoration(color: Colors.grey[800], shape: BoxShape.circle),
                    child: Center(child: SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyan[300]))),
                  )
                : Material(
                    color: hasText ? Colors.cyan : (speech.listening ? Colors.redAccent : Colors.grey[800]!),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {
                        if (hasText) { _sendPrompt(); }
                        else if (speech.listening) { ref.read(speechProvider.notifier).stopListening(); }
                        else if (speech.available) { HapticFeedback.heavyImpact(); ref.read(speechProvider.notifier).startListening(); }
                      },
                      child: Center(child: Icon(
                        hasText ? Icons.arrow_upward : speech.listening ? Icons.stop : Icons.mic,
                        color: Colors.white, size: 20,
                      )),
                    ),
                  ),
          ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pulsing red dot indicator for active recording
// ---------------------------------------------------------------------------

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Container(
        width: 10, height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.redAccent.withValues(alpha: 0.5 + _controller.value * 0.5),
        ),
      ),
    );
  }
}
