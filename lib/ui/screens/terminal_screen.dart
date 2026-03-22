import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:xterm/xterm.dart';

import '../../core/log.dart';
import '../../core/pairing.dart';
import '../../core/protocol.dart';
import '../../core/session_history.dart';
import '../../relay/session.dart';

class TerminalScreen extends StatefulWidget {
  final PairingUri pairing;

  const TerminalScreen({super.key, required this.pairing});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> with WidgetsBindingObserver {
  late final RelaySession _session;
  late final Terminal _terminal;
  StreamSubscription? _outputSub;
  StreamSubscription? _eventSub;


  // Structured agent event state
  bool _hasStructuredEvents = false;
  bool _showStructuredView = false;
  bool _agentBusy = false;
  final List<_AgentMessage> _agentMessages = [];
  final ScrollController _agentScrollController = ScrollController();

  // Speech-to-text
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;
  String _liveTranscript = '';

  // Prompt bar controller (shared between typed input and STT)
  final TextEditingController _promptController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _terminal = Terminal(
      maxLines: 10000,
      onOutput: (data) {
        _session.sendInput(Uint8List.fromList(data.codeUnits));
      },
      onResize: (width, height, pixelWidth, pixelHeight) {
        _session.sendResize(width, height);
      },
    );

    _session = RelaySession(pairing: widget.pairing);
    _session.addListener(_onStateChanged);

    _initSpeech();

    _outputSub = _session.output.listen((bytes) {
      _terminal.write(utf8.decode(bytes, allowMalformed: true));
    });

    _eventSub = _session.events.listen((msg) {
      switch (msg) {
        case SessionEnded(exitCode: final code):
          _showSnackBar('Session ended (exit code: $code)');
          SessionHistory.update(
            widget.pairing.sessionId,
            lastActiveAt: DateTime.now(),
            endReason: SessionEndReason.hostEnded,
          );
        case VersionNotice(minimumVersion: final v):
          _showSnackBar('Minimum version required: $v');

        // ── Structured agent events ──
        case AgentSessionInit(model: final model, tools: final tools):
          setState(() {
            _hasStructuredEvents = true;
            _showStructuredView = true;
            _agentMessages.add(_AgentMessage(
              type: _MsgType.system,
              text: 'Model: $model\nTools: ${tools.join(", ")}',
            ));
          });
          _scrollAgentToBottom();

        case AgentTurnStarted():
          setState(() {
            _agentBusy = true;
            _agentMessages.add(_AgentMessage(
              type: _MsgType.turnMarker,
              text: 'Turn started...',
            ));
          });
          _scrollAgentToBottom();

        case AgentTextDelta(text: final text):
          setState(() {
            // Append to the last text message or create a new one.
            if (_agentMessages.isNotEmpty && _agentMessages.last.type == _MsgType.text) {
              _agentMessages.last.text += text;
            } else {
              _agentMessages.add(_AgentMessage(type: _MsgType.text, text: text));
            }
          });
          _scrollAgentToBottom();

        case AgentThinkingDelta(text: final text):
          setState(() {
            if (_agentMessages.isNotEmpty && _agentMessages.last.type == _MsgType.thinking) {
              _agentMessages.last.text += text;
            } else {
              _agentMessages.add(_AgentMessage(type: _MsgType.thinking, text: text));
            }
          });
          _scrollAgentToBottom();

        case AgentTextBlock(text: final text):
          setState(() {
            _agentMessages.add(_AgentMessage(type: _MsgType.text, text: text));
          });
          _scrollAgentToBottom();

        case AgentToolUseStart(name: final name, id: final id, input: final input):
          setState(() {
            _agentMessages.add(_AgentMessage(
              type: _MsgType.toolCall,
              text: name,
              toolId: id,
              toolInput: input,
            ));
          });
          _scrollAgentToBottom();

        case AgentToolResult(id: final id, content: final content, isError: final isError):
          setState(() {
            _agentMessages.add(_AgentMessage(
              type: isError ? _MsgType.toolError : _MsgType.toolResult,
              text: content,
              toolId: id,
            ));
          });
          _scrollAgentToBottom();

        case AgentTurnCompleted(status: final status):
          setState(() {
            _agentBusy = false;
            _agentMessages.add(_AgentMessage(
              type: _MsgType.turnMarker,
              text: 'Turn $status',
            ));
          });
          _scrollAgentToBottom();

        case AgentSessionResult(result: final result, durationMs: final ms, numTurns: final turns):
          setState(() {
            _agentMessages.add(_AgentMessage(
              type: _MsgType.system,
              text: 'Done (${(ms / 1000).toStringAsFixed(1)}s, $turns turn${turns == 1 ? "" : "s"})\n$result',
            ));
          });
          _scrollAgentToBottom();

        default:
          break;
      }
    });

    _session.connect();
  }

  // ---------------------------------------------------------------------------
  // Speech-to-text
  // ---------------------------------------------------------------------------

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onStatus: (status) {
        log('[stt] status: $status');
        if (status == 'notListening' && _isListening) {
          // Recognition stopped (e.g. silence timeout) — finalize
          setState(() => _isListening = false);
          _onSpeechDone();
        }
      },
      onError: (error) {
        log('[stt] error: ${error.errorMsg}');
        setState(() => _isListening = false);
        if (_liveTranscript.isNotEmpty) {
          _onSpeechDone();
        }
      },
    );
    log('[stt] available: $_speechAvailable');
    if (mounted) setState(() {});
  }

  void _startListening() {
    if (!_speechAvailable || _isListening) return;
    HapticFeedback.heavyImpact();
    setState(() {
      _isListening = true;
      _liveTranscript = '';
    });
    _speech.listen(
      onResult: _onSpeechResult,
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.dictation,
        cancelOnError: false,
        partialResults: true,
      ),
    );
  }

  void _stopListening() {
    if (!_isListening) return;
    _speech.stop();
    setState(() => _isListening = false);
    _onSpeechDone();
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() {
      _liveTranscript = result.recognizedWords;
    });
  }

  void _onSpeechDone() {
    if (_liveTranscript.trim().isEmpty) return;
    HapticFeedback.mediumImpact();
    // Fill the prompt bar with the transcript for editing before send.
    setState(() {
      _promptController.text = _liveTranscript.trim();
      _promptController.selection = TextSelection.fromPosition(
        TextPosition(offset: _promptController.text.length),
      );
      _liveTranscript = '';
    });
  }

  void _onStateChanged() {
    if (mounted) {
      setState(() {
        // Auto-enable structured view when connected to a structured tool.
        if (_session.state == SessionState.connected && _session.isStructuredTool) {
          _hasStructuredEvents = true;
          _showStructuredView = true;
        }
      });
    }

    // Persist session history on key state transitions
    final state = _session.state;
    if (state == SessionState.connected) {
      _saveSessionRecord();
    } else if (state == SessionState.error) {
      SessionHistory.update(
        widget.pairing.sessionId,
        lastActiveAt: DateTime.now(),
        endReason: SessionEndReason.connectionLost,
      );
    }
  }

  void _saveSessionRecord() {
    final record = SessionRecord.fromPairing(widget.pairing).copyWith(
      toolName: _session.toolName,
      lastActiveAt: DateTime.now(),
    );
    SessionHistory.upsert(record);
  }

  void _showSnackBar(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  // ---------------------------------------------------------------------------
  // App lifecycle
  // ---------------------------------------------------------------------------

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        log('[lifecycle] app backgrounded, pausing heartbeat');
        _session.pauseHeartbeat();

      case AppLifecycleState.resumed:
        log('[lifecycle] app resumed, checking connection');
        _session.resumeOrReconnect();

      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  // ---------------------------------------------------------------------------
  // Back button
  // ---------------------------------------------------------------------------

  Future<bool> _onBackPressed() async {
    // If not connected, just go back
    if (_session.state == SessionState.disconnected ||
        _session.state == SessionState.error) {
      return true;
    }

    // Prompt the user
    final shouldDisconnect = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnect?'),
        content: const Text('This will end your terminal session.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (shouldDisconnect == true) {
      await _session.disconnect();
      SessionHistory.update(
        widget.pairing.sessionId,
        lastActiveAt: DateTime.now(),
        endReason: SessionEndReason.userDisconnected,
      );
      return true;
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _session.removeListener(_onStateChanged);
    _outputSub?.cancel();
    _eventSub?.cancel();
    _promptController.dispose();
    _agentScrollController.dispose();
    if (_isListening) _speech.stop();
    _session.dispose();
    super.dispose();
  }

  void _close() async {
    if (await _onBackPressed()) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Send control characters / special keys
  // ---------------------------------------------------------------------------

  void _sendBytes(List<int> bytes) {
    HapticFeedback.lightImpact();
    _session.sendInput(Uint8List.fromList(bytes));
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
      _session.sendInput(Uint8List.fromList(utf8.encode(data.text!)));
      HapticFeedback.lightImpact();
    }
  }

  // ---------------------------------------------------------------------------
  // Status bar
  // ---------------------------------------------------------------------------

  Widget _buildStatusBar() {
    final (icon, label, color) = switch (_session.state) {
      SessionState.disconnected     => (Icons.link_off, 'Disconnected', Colors.grey),
      SessionState.connecting       => (Icons.sync, 'Connecting...', Colors.orange),
      SessionState.waitingForPeer   => (Icons.hourglass_empty, 'Waiting for host...', Colors.orange),
      SessionState.handshaking      => (Icons.handshake, 'Key exchange...', Colors.amber),
      SessionState.awaitingConfirm  => (Icons.handshake, 'Verifying...', Colors.amber),
      SessionState.connected        => (Icons.lock, 'Connected (E2E encrypted)', Colors.green),
      SessionState.reconnecting     => (Icons.sync, 'Reconnecting...', Colors.orange),
      SessionState.error            => (Icons.error, _session.error ?? 'Error', Colors.red),
    };

    final showReconnect = _session.state == SessionState.error ||
        _session.state == SessionState.disconnected;

    return Container(
      color: Colors.grey[900],
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: color, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_session.toolName != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                _session.toolName!,
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ),
          if (showReconnect)
            GestureDetector(
              onTap: () => _session.connect(),
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
                // Drag handle
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[700],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Control section
                _actionSection('Control', [
                  _actionTile(Icons.stop_circle_outlined, 'Interrupt', 'Ctrl+C', () => _sendCtrl('C')),
                  _actionTile(Icons.logout, 'EOF', 'Ctrl+D', () => _sendCtrl('D')),
                  _actionTile(Icons.pause_circle_outline, 'Suspend', 'Ctrl+Z', () => _sendCtrl('Z')),
                  _actionTile(Icons.refresh, 'Clear', 'Ctrl+L', () => _sendCtrl('L')),
                ]),
                const SizedBox(height: 12),
                // Navigate section
                _actionSection('Navigate', [
                  _actionTile(Icons.arrow_upward, 'Previous', 'Up', () => _sendBytes([0x1b, 0x5b, 0x41])),
                  _actionTile(Icons.arrow_downward, 'Next', 'Down', () => _sendBytes([0x1b, 0x5b, 0x42])),
                  _actionTile(Icons.keyboard_tab, 'Tab', 'Tab', () => _sendBytes([0x09])),
                  _actionTile(Icons.first_page, 'Escape', 'Esc', () => _sendBytes([0x1b])),
                ]),
                const SizedBox(height: 12),
                // Edit section
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
          child: Text(
            title,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: children,
        ),
      ],
    );
  }

  Widget _actionTile(IconData icon, String label, String shortcut, VoidCallback onTap) {
    return Material(
      color: Colors.grey[800],
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          onTap();
          Navigator.pop(context);
        },
        child: Container(
          width: 80,
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              if (shortcut.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    shortcut,
                    style: TextStyle(color: Colors.grey[600], fontSize: 10),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // Compose bar (editable preview of transcribed speech)
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // Live listening overlay (shown while recording, terminal view only)
  // ---------------------------------------------------------------------------

  Widget _buildListeningOverlay() {
    return Positioned(
      bottom: 80,
      left: 24,
      right: 24,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey[900]?.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            const _PulsingDot(),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _liveTranscript.isEmpty ? 'Listening...' : _liveTranscript,
                style: TextStyle(
                  color: _liveTranscript.isEmpty ? Colors.grey[400] : Colors.white,
                  fontSize: 14,
                  fontStyle: _liveTranscript.isEmpty ? FontStyle.italic : FontStyle.normal,
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
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Mic FAB only shows in terminal view (structured view has mic in prompt bar).
    final showMicFab = !_showStructuredView &&
        _speechAvailable &&
        _session.state == SessionState.connected;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _onBackPressed()) {
          navigator.pop();
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: _showStructuredView,
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text('Terminal'),
          backgroundColor: Colors.grey[900],
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _close,
          ),
          actions: [
            if (_session.state == SessionState.error ||
                _session.state == SessionState.disconnected)
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Reconnect',
                onPressed: () => _session.connect(),
              ),
            // Toggle between structured and terminal views.
            if (_hasStructuredEvents)
              IconButton(
                icon: Icon(
                  _showStructuredView ? Icons.terminal : Icons.auto_awesome,
                ),
                tooltip: _showStructuredView ? 'Terminal view' : 'Structured view',
                onPressed: () => setState(() => _showStructuredView = !_showStructuredView),
              ),
            // Terminal actions (only in terminal view).
            if (!_showStructuredView)
              IconButton(
                icon: const Icon(Icons.keyboard_command_key),
                tooltip: 'Terminal actions',
                onPressed: _showTerminalActions,
              ),
          ],
        ),
        body: Stack(
          children: [
            // Main content — terminal or structured view
            Column(
              children: [
                _buildStatusBar(),
                Expanded(
                  child: _showStructuredView
                      ? _buildStructuredView()
                      : TerminalView(
                          _terminal,
                          autofocus: true,
                        ),
                ),
              ],
            ),

            // Live transcript overlay while listening
            if (_isListening && !_showStructuredView) _buildListeningOverlay(),
            // Floating mic button
            if (showMicFab)
              Positioned(
                right: 16,
                bottom: (_showStructuredView ? 80 : 24) +
                    MediaQuery.of(context).padding.bottom,
                child: FloatingActionButton(
                  backgroundColor: _isListening ? Colors.redAccent : Colors.grey[800],
                  onPressed: () {
                    if (_isListening) {
                      _stopListening();
                    } else {
                      _startListening();
                    }
                  },
                  tooltip: _isListening ? 'Tap to stop' : 'Tap to speak',
                  child: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    color: _isListening ? Colors.white : Colors.grey[400],
                    size: 24,
                  ),
                ),
              ),
           ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Structured agent view
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

  Widget _buildStructuredView() {
    return Column(
      children: [
        Expanded(
          child: _agentMessages.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome, color: Colors.cyan[300], size: 40),
                        const SizedBox(height: 16),
                        Text(
                          'Connected to ${_session.toolName ?? "agent"}',
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
                  itemCount: _agentMessages.length,
                  itemBuilder: (context, index) {
                    final msg = _agentMessages[index];
                    return _buildAgentMessageCard(msg);
                  },
                ),
        ),
        // Prompt input bar for structured mode.
        _buildPromptBar(),
      ],
    );
  }

  Widget _buildAgentMessageCard(_AgentMessage msg) {
    return switch (msg.type) {
      _MsgType.system => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blueGrey.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            msg.text,
            style: TextStyle(color: Colors.grey[400], fontSize: 12, fontFamily: 'monospace'),
          ),
        ),
      ),
      _MsgType.text => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: SelectableText(
          msg.text,
          style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
        ),
      ),
      _MsgType.thinking => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.purple.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.psychology, color: Colors.purple[300], size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  msg.text,
                  style: TextStyle(color: Colors.purple[200], fontSize: 13, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        ),
      ),
      _MsgType.toolCall => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.cyan.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.cyan.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.build, color: Colors.cyan[300], size: 16),
                  const SizedBox(width: 6),
                  Text(
                    msg.text,
                    style: TextStyle(color: Colors.cyan[200], fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
              if (msg.toolInput != null && msg.toolInput!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  msg.toolInput!.length > 200 ? '${msg.toolInput!.substring(0, 200)}...' : msg.toolInput!,
                  style: TextStyle(color: Colors.grey[500], fontSize: 11, fontFamily: 'monospace'),
                ),
              ],
            ],
          ),
        ),
      ),
      _MsgType.toolResult => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            msg.text.length > 300 ? '${msg.text.substring(0, 300)}...' : msg.text,
            style: TextStyle(color: Colors.grey[500], fontSize: 11, fontFamily: 'monospace'),
            maxLines: 10,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      _MsgType.toolError => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  msg.text,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
      _MsgType.turnMarker => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(child: Divider(color: Colors.grey[700])),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                msg.text,
                style: TextStyle(color: Colors.grey[600], fontSize: 11),
              ),
            ),
            Expanded(child: Divider(color: Colors.grey[700])),
          ],
        ),
      ),
    };
  }

  void _sendPrompt() {
    final text = _promptController.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    _session.sendAgentPrompt(text);
    _promptController.clear();
  }

  Widget _buildPromptBar() {
    final hasText = _promptController.text.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: Border(top: BorderSide(color: Colors.grey[800]!)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _promptController,
                enabled: !_agentBusy,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: _isListening
                      ? 'Listening...'
                      : _agentBusy
                          ? 'Agent is working...'
                          : 'Send a prompt...',
                  hintStyle: TextStyle(color: _isListening ? Colors.redAccent : Colors.grey[600]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: Colors.grey[700]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: Colors.grey[700]!),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: Colors.grey[800]!),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  isDense: true,
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendPrompt(),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 8),
            // Right button: send / mic / busy spinner — same size, no layout shift
            SizedBox(
              width: 40,
              height: 40,
              child: _agentBusy
                  ? Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.cyan[300],
                          ),
                        ),
                      ),
                    )
                  : Material(
                      color: hasText ? Colors.cyan : (_isListening ? Colors.redAccent : Colors.grey[800]!),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () {
                          if (hasText) {
                            _sendPrompt();
                          } else if (_isListening) {
                            _stopListening();
                          } else if (_speechAvailable) {
                            _startListening();
                          }
                        },
                        child: Center(
                          child: Icon(
                            hasText
                                ? Icons.arrow_upward
                                : _isListening
                                    ? Icons.stop
                                    : Icons.mic,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Structured agent message model
// ---------------------------------------------------------------------------

enum _MsgType { system, text, thinking, toolCall, toolResult, toolError, turnMarker }

class _AgentMessage {
  _MsgType type;
  String text;
  String? toolId;
  String? toolInput;

  _AgentMessage({
    required this.type,
    required this.text,
    this.toolId,
    this.toolInput,
  });
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
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.redAccent.withValues(alpha: 0.5 + _controller.value * 0.5),
        ),
      ),
    );
  }
}
