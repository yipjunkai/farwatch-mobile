import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';

import '../../core/pairing.dart';
import '../../providers/agent_state_provider.dart';
import '../../providers/speech_provider.dart';
import '../../providers/terminal_session_provider.dart';
import '../../relay/session.dart';
import '../../theme/farwatch_colors.dart';
import '../adaptive.dart';
import '../widgets/agent/structured_view.dart';
import '../widgets/terminal/connection_status_bar.dart';
import '../widgets/terminal/listening_overlay.dart';
import '../widgets/terminal/mic_button.dart';
import '../widgets/terminal/terminal_actions_sheet.dart';

class TerminalScreen extends ConsumerStatefulWidget {
  final PairingUri pairing;

  const TerminalScreen({super.key, required this.pairing});

  @override
  ConsumerState<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends ConsumerState<TerminalScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(terminalSessionProvider(widget.pairing).notifier).connect();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // App lifecycle
  // ---------------------------------------------------------------------------

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final notifier =
        ref.read(terminalSessionProvider(widget.pairing).notifier);
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
  // Back / disconnect
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
  // Terminal input helpers
  // ---------------------------------------------------------------------------

  void _sendBytes(List<int> bytes) {
    HapticFeedback.lightImpact();
    ref
        .read(terminalSessionProvider(widget.pairing).notifier)
        .sendInput(Uint8List.fromList(bytes));
  }

  void _sendCtrl(String char) {
    final code = char.toUpperCase().codeUnitAt(0) - 0x40;
    if (code >= 1 && code <= 26) _sendBytes([code]);
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
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final ts = ref.watch(terminalSessionProvider(widget.pairing));
    final agent = ref.watch(agentStateProvider);
    final speech = ref.watch(speechProvider);

    // Check for pending toast messages.
    final toast = ref
        .read(terminalSessionProvider(widget.pairing).notifier)
        .consumeToast();
    if (toast != null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => showAdaptiveToast(context, toast));
    }

    final showMicFab = !agent.showStructuredView &&
        speech.available &&
        ts.sessionState == SessionState.connected;

    final terminal =
        ref.read(terminalSessionProvider(widget.pairing).notifier).terminal;

    final body = Stack(
      children: [
        Column(
          children: [
            ConnectionStatusBar(pairing: widget.pairing),
            Expanded(
              child: agent.showStructuredView
                  ? StructuredView(pairing: widget.pairing)
                  : TerminalView(terminal, autofocus: true),
            ),
          ],
        ),
        if (speech.listening && !agent.showStructuredView)
          const ListeningOverlay(),
        if (showMicFab)
          Positioned(
            right: 16,
            bottom: (agent.showStructuredView ? 80 : 24) +
                MediaQuery.of(context).padding.bottom,
            child: const MicButton(),
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
          ? _buildCupertinoShell(body, ts, agent)
          : _buildMaterialShell(body, ts, agent),
    );
  }

  // ---------------------------------------------------------------------------
  // Shell (scaffold + app bar)
  // ---------------------------------------------------------------------------

  Widget _buildMaterialShell(
      Widget body, TerminalSessionState ts, AgentState agent) {
    final c = context.colors;
    return Scaffold(
      resizeToAvoidBottomInset: agent.showStructuredView,
      backgroundColor: c.background,
      appBar: AppBar(
        title: const Text('Terminal'),
        backgroundColor: c.surfacePrimary,
        foregroundColor: c.textPrimary,
        leading:
            IconButton(icon: const Icon(Icons.arrow_back), onPressed: _close),
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
              icon: Icon(agent.showStructuredView
                  ? Icons.terminal
                  : Icons.auto_awesome),
              tooltip: agent.showStructuredView
                  ? 'Terminal view'
                  : 'Structured view',
              onPressed: () =>
                  ref.read(agentStateProvider.notifier).toggleView(),
            ),
          if (!agent.showStructuredView)
            IconButton(
              icon: const Icon(Icons.keyboard_command_key),
              tooltip: 'Terminal actions',
              onPressed: () => showTerminalActions(
                context,
                onSendBytes: _sendBytes,
                onSendCtrl: _sendCtrl,
                onPaste: _pasteClipboard,
              ),
            ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildCupertinoShell(
      Widget body, TerminalSessionState ts, AgentState agent) {
    final c = context.colors;
    return CupertinoPageScaffold(
      resizeToAvoidBottomInset: agent.showStructuredView,
      backgroundColor: c.background,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: c.navBarBackground,
        middle: Text('Terminal', style: TextStyle(color: c.textPrimary)),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: _close,
          child: Icon(CupertinoIcons.back, color: c.accent, size: 22),
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
                child: Icon(CupertinoIcons.refresh,
                    color: c.textPrimary, size: 20),
              ),
            if (agent.hasStructuredEvents)
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: Size.zero,
                onPressed: () =>
                    ref.read(agentStateProvider.notifier).toggleView(),
                child: Icon(
                  agent.showStructuredView
                      ? Icons.terminal
                      : CupertinoIcons.sparkles,
                  color: c.textPrimary,
                  size: 20,
                ),
              ),
            if (!agent.showStructuredView)
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: Size.zero,
                onPressed: () => showTerminalActions(
                  context,
                  onSendBytes: _sendBytes,
                  onSendCtrl: _sendCtrl,
                  onPaste: _pasteClipboard,
                ),
                child: Icon(CupertinoIcons.command,
                    color: c.textPrimary, size: 20),
              ),
          ],
        ),
      ),
      child: SafeArea(top: false, child: body),
    );
  }
}
