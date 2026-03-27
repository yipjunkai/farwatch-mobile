import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
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
import '../adaptive.dart';

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

  // Permission tracking: permission ID → resolved status (null = pending)
  final Map<String, String?> _pendingPermissions = {};

  // Todo list state
  List<TodoItem> _todos = [];

  // Cost tracking (cumulative)
  double _sessionCostUsd = 0.0;
  int _totalInputTokens = 0;
  int _totalOutputTokens = 0;

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
          _showToast('Session ended (exit code: $code)');
          SessionHistory.update(
            widget.pairing.sessionId,
            lastActiveAt: DateTime.now(),
            endReason: SessionEndReason.hostEnded,
          );
        case VersionNotice(minimumVersion: final v):
          _showToast('Minimum version required: $v');

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

        case AgentToolUseStart(id: final id, name: final name, input: final input):
          setState(() {
            _agentMessages.add(_AgentMessage(
              type: _MsgType.toolCall,
              text: name,
              toolId: id,
              toolInput: input,
            ));
          });
          _scrollAgentToBottom();

        case AgentToolResult(id: final id, content: final result, isError: final isError):
          setState(() {
            _agentMessages.add(_AgentMessage(
              type: isError ? _MsgType.toolError : _MsgType.toolResult,
              text: result,
              toolId: id,
            ));
          });
          _scrollAgentToBottom();

        case AgentTurnCompleted():
          setState(() => _agentBusy = false);
          _scrollAgentToBottom();

        case AgentSessionResult(result: final result, isError: final isError):
          setState(() {
            _agentBusy = false;
            _agentMessages.add(_AgentMessage(
              type: isError ? _MsgType.toolError : _MsgType.text,
              text: result,
            ));
          });
          _scrollAgentToBottom();

        case AgentPermissionRequest(id: final id, tool: final name, title: final desc, metadata: final input):
          setState(() {
            _pendingPermissions[id] = null;
            _agentMessages.add(_AgentMessage(
              type: _MsgType.permissionRequest,
              text: desc,
              toolId: id,
              toolInput: input,
              toolName: name,
            ));
          });
          _scrollAgentToBottom();
          HapticFeedback.heavyImpact();

        case AgentPermissionResolved(id: final id, response: final response):
          setState(() {
            _pendingPermissions[id] = response;
          });

        case AgentCostUpdate(costUsd: final cost, inputTokens: final input, outputTokens: final output):
          setState(() {
            _sessionCostUsd = cost;
            _totalInputTokens = input;
            _totalOutputTokens = output;
          });

        case AgentTodoUpdate(todos: final items):
          setState(() {
            _todos = items;
          });

        // Remaining SecureMessage subtypes are handled elsewhere or ignored.
        case PtyInput() || PtyOutput() || Resize() || Heartbeat() ||
             ClipboardMsg() || ReadOnlyMsg() || VoiceCommand() ||
             AgentTextBlock() || AgentCommand() || UnknownMessage():
          break;
      }
    });

    _session.connect();
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onError: (error) {
        log('[stt] error: ${error.errorMsg}');
        if (mounted) setState(() => _isListening = false);
      },
      onStatus: (status) {
        log('[stt] status: $status');
        if (status == 'done' && mounted) {
          setState(() => _isListening = false);
          _onSpeechDone();
        }
      },
    );
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

  void _showToast(String text) {
    if (!mounted) return;
    showAdaptiveToast(context, text);
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
  // Back button / disconnect
  // ---------------------------------------------------------------------------

  Future<bool> _onBackPressed() async {
    if (_session.state == SessionState.disconnected ||
        _session.state == SessionState.error) {
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
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                onPressed: () => _session.connect(),
                child: Icon(CupertinoIcons.refresh, size: 16, color: Colors.grey[400]),
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
                textAlign: TextAlign.center,
              ),
              if (shortcut.isNotEmpty)
                Text(
                  shortcut,
                  style: TextStyle(color: Colors.grey[500], fontSize: 10),
                ),
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
  // Mic button
  // ---------------------------------------------------------------------------

  Widget _buildMicButton() {
    if (isApplePlatform) {
      return CupertinoButton(
        padding: const EdgeInsets.all(14),
        color: _isListening
            ? CupertinoColors.destructiveRed
            : const Color(0xCC3A3A3C),
        borderRadius: BorderRadius.circular(28),
        onPressed: () {
          if (_isListening) {
            _stopListening();
          } else {
            _startListening();
          }
        },
        child: Icon(
          _isListening ? CupertinoIcons.mic_fill : CupertinoIcons.mic,
          color: _isListening ? CupertinoColors.white : Colors.grey[400],
          size: 22,
        ),
      );
    }
    return FloatingActionButton(
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
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final showMicFab = !_showStructuredView &&
        _speechAvailable &&
        _session.state == SessionState.connected;

    final bodyContent = Stack(
      children: [
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
        if (_isListening && !_showStructuredView) _buildListeningOverlay(),
        if (showMicFab)
          Positioned(
            right: 16,
            bottom: (_showStructuredView ? 80 : 24) +
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
        if (await _onBackPressed()) {
          navigator.pop();
        }
      },
      child: isApplePlatform
          ? _buildCupertinoShell(bodyContent)
          : _buildMaterialShell(bodyContent),
    );
  }

  Widget _buildMaterialShell(Widget body) {
    return Scaffold(
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
          if (_hasStructuredEvents)
            IconButton(
              icon: Icon(
                _showStructuredView ? Icons.terminal : Icons.auto_awesome,
              ),
              tooltip: _showStructuredView ? 'Terminal view' : 'Structured view',
              onPressed: () => setState(() => _showStructuredView = !_showStructuredView),
            ),
          if (!_showStructuredView)
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

  Widget _buildCupertinoShell(Widget body) {
    return CupertinoPageScaffold(
      resizeToAvoidBottomInset: _showStructuredView,
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
            if (_session.state == SessionState.error ||
                _session.state == SessionState.disconnected)
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: Size.zero,
                onPressed: () => _session.connect(),
                child: const Icon(CupertinoIcons.refresh, color: CupertinoColors.white, size: 20),
              ),
            if (_hasStructuredEvents)
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: Size.zero,
                onPressed: () => setState(() => _showStructuredView = !_showStructuredView),
                child: Icon(
                  _showStructuredView ? Icons.terminal : CupertinoIcons.sparkles,
                  color: CupertinoColors.white,
                  size: 20,
                ),
              ),
            if (!_showStructuredView)
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

  Widget _buildCostTicker() {
    if (_sessionCostUsd == 0.0 && _totalInputTokens == 0) return const SizedBox.shrink();

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
          Text(
            '\$${_sessionCostUsd.toStringAsFixed(4)}',
            style: TextStyle(color: Colors.grey[400], fontSize: 12, fontFamily: 'monospace'),
          ),
          const SizedBox(width: 12),
          Icon(Icons.arrow_downward, color: Colors.grey[600], size: 12),
          const SizedBox(width: 3),
          Text(
            formatTokens(_totalInputTokens),
            style: TextStyle(color: Colors.grey[500], fontSize: 11),
          ),
          const SizedBox(width: 8),
          Icon(Icons.arrow_upward, color: Colors.grey[600], size: 12),
          const SizedBox(width: 3),
          Text(
            formatTokens(_totalOutputTokens),
            style: TextStyle(color: Colors.grey[500], fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildTodoList() {
    if (_todos.isEmpty) return const SizedBox.shrink();

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
              Text(
                'Tasks',
                style: TextStyle(color: Colors.blueGrey[200], fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                '${_todos.where((t) => t.status == "completed").length}/${_todos.length}',
                style: TextStyle(color: Colors.grey[500], fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ..._todos.map((todo) {
            final isCompleted = todo.status == 'completed';
            final isCancelled = todo.status == 'cancelled';
            final isInProgress = todo.status == 'in_progress';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isCompleted
                        ? Icons.check_circle
                        : isCancelled
                            ? Icons.cancel
                            : isInProgress
                                ? Icons.play_circle_filled
                                : Icons.radio_button_unchecked,
                    color: isCompleted
                        ? Colors.green[400]
                        : isCancelled
                            ? Colors.grey[600]
                            : isInProgress
                                ? Colors.blue[400]
                                : Colors.grey[600],
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  if (todo.priority == 'high')
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(top: 4, right: 4),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.redAccent,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      todo.content,
                      style: TextStyle(
                        color: isCompleted || isCancelled ? Colors.grey[600] : Colors.grey[300],
                        fontSize: 12,
                        decoration: isCancelled ? TextDecoration.lineThrough : null,
                      ),
                    ),
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
    return Column(
      children: [
        _buildCostTicker(),
        _buildTodoList(),
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
      _MsgType.permissionRequest => _buildPermissionCard(msg),
    };
  }

  Widget _buildPermissionCard(_AgentMessage msg) {
    final permId = msg.toolId ?? '';
    final resolved = _pendingPermissions[permId];
    final isPending = resolved == null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: GlassContainer(
        padding: const EdgeInsets.all(12),
        color: isPending
            ? Colors.amber.withValues(alpha: 0.1)
            : Colors.grey.withValues(alpha: 0.08),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isPending ? Icons.security : Icons.check_circle_outline,
                  color: isPending ? Colors.amber[300] : Colors.grey[500],
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  msg.toolName ?? 'Tool',
                  style: TextStyle(
                    color: isPending ? Colors.amber[200] : Colors.grey[500],
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                if (!isPending) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: resolved == 'allow'
                          ? Colors.green.withValues(alpha: 0.2)
                          : Colors.red.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      resolved == 'allow' ? 'Allowed' : 'Denied',
                      style: TextStyle(
                        color: resolved == 'allow' ? Colors.green[300] : Colors.red[300],
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(
              msg.text,
              style: TextStyle(
                color: isPending ? Colors.white : Colors.grey[500],
                fontSize: 13,
              ),
            ),
            if (msg.toolInput != null && msg.toolInput!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                msg.toolInput!.length > 150 ? '${msg.toolInput!.substring(0, 150)}...' : msg.toolInput!,
                style: TextStyle(color: Colors.grey[600], fontSize: 11, fontFamily: 'monospace'),
              ),
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
    if (isApplePlatform) {
      return Row(
        children: [
          Expanded(
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: Colors.red.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              onPressed: () {
                HapticFeedback.mediumImpact();
                _session.sendDenyToolUse(permId);
                setState(() => _pendingPermissions[permId] = 'deny');
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
                _session.sendApproveToolUse(permId);
                setState(() => _pendingPermissions[permId] = 'allow');
              },
              child: Text('Allow', style: TextStyle(color: Colors.green[200], fontSize: 13)),
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 36,
            child: OutlinedButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                _session.sendDenyToolUse(permId);
                setState(() => _pendingPermissions[permId] = 'deny');
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
                _session.sendApproveToolUse(permId);
                setState(() => _pendingPermissions[permId] = 'allow');
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
      ],
    );
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

    if (isApplePlatform) return _buildCupertinoPromptBar(hasText);
    return _buildMaterialPromptBar(hasText);
  }

  Widget _buildCupertinoPromptBar(bool hasText) {
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
            child: Row(
              children: [
                Expanded(
                  child: CupertinoTextField(
                    controller: _promptController,
                    enabled: !_agentBusy,
                    style: const TextStyle(color: CupertinoColors.white, fontSize: 14),
                    placeholder: _isListening
                        ? 'Listening...'
                        : _agentBusy
                            ? 'Agent is working...'
                            : 'Send a prompt...',
                    placeholderStyle: TextStyle(
                      color: _isListening ? CupertinoColors.destructiveRed : Colors.grey[600],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C2E),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendPrompt(),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 36,
                  height: 36,
                  child: _agentBusy
                      ? const Center(
                          child: CupertinoActivityIndicator(),
                        )
                      : CupertinoButton(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          color: hasText
                              ? CupertinoColors.systemTeal
                              : (_isListening
                                  ? CupertinoColors.destructiveRed
                                  : const Color(0xFF3A3A3C)),
                          borderRadius: BorderRadius.circular(18),
                          onPressed: () {
                            if (hasText) {
                              _sendPrompt();
                            } else if (_isListening) {
                              _stopListening();
                            } else if (_speechAvailable) {
                              _startListening();
                            }
                          },
                          child: Icon(
                            hasText
                                ? CupertinoIcons.arrow_up
                                : _isListening
                                    ? CupertinoIcons.stop_fill
                                    : CupertinoIcons.mic,
                            color: CupertinoColors.white,
                            size: 18,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMaterialPromptBar(bool hasText) {
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

enum _MsgType { system, text, thinking, toolCall, toolResult, toolError, turnMarker, permissionRequest }

class _AgentMessage {
  _MsgType type;
  String text;
  String? toolId;
  String? toolInput;
  /// Tool name (used for permission request cards).
  String? toolName;

  _AgentMessage({
    required this.type,
    required this.text,
    this.toolId,
    this.toolInput,
    this.toolName,
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
