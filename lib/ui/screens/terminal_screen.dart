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
  bool _toolbarVisible = false;

  // Speech-to-text
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;
  String _liveTranscript = '';
  double _confidence = 0.0;

  // Compose bar (shown after STT finishes)
  bool _composeVisible = false;
  final TextEditingController _composeController = TextEditingController();

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
      _confidence = 0.0;
      _composeVisible = false;
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
      if (result.hasConfidenceRating) {
        _confidence = result.confidence;
      }
    });
  }

  void _onSpeechDone() {
    if (_liveTranscript.trim().isEmpty) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _composeVisible = true;
      _composeController.text = _liveTranscript.trim();
      _composeController.selection = TextSelection.fromPosition(
        TextPosition(offset: _composeController.text.length),
      );
    });
  }

  void _sendComposedText() {
    final text = _composeController.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    _session.sendVoiceCommand(
      transcript: text,
      confidence: _confidence,
    );
    setState(() {
      _composeVisible = false;
      _composeController.clear();
      _liveTranscript = '';
    });
  }

  void _cancelCompose() {
    setState(() {
      _composeVisible = false;
      _composeController.clear();
      _liveTranscript = '';
    });
  }

  void _onStateChanged() {
    if (mounted) setState(() {});

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
    _composeController.dispose();
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

  Widget _buildToolbar() {
    return Container(
      color: Colors.grey[850],
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  _toolbarKey('Ctrl-C', () => _sendCtrl('C')),
                  _toolbarKey('Ctrl-D', () => _sendCtrl('D')),
                  _toolbarKey('Ctrl-Z', () => _sendCtrl('Z')),
                  _toolbarKey('Ctrl-L', () => _sendCtrl('L')),
                  _toolbarKey('Ctrl-A', () => _sendCtrl('A')),
                  _toolbarKey('Ctrl-E', () => _sendCtrl('E')),
                  _toolbarKey('Ctrl-R', () => _sendCtrl('R')),
                  _toolbarKey('Ctrl-W', () => _sendCtrl('W')),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  _toolbarKey('Tab', () => _sendBytes([0x09])),
                  _toolbarKey('Esc', () => _sendBytes([0x1b])),
                  _toolbarKey('\u2191', () => _sendBytes([0x1b, 0x5b, 0x41])),
                  _toolbarKey('\u2193', () => _sendBytes([0x1b, 0x5b, 0x42])),
                  _toolbarKey('\u2190', () => _sendBytes([0x1b, 0x5b, 0x44])),
                  _toolbarKey('\u2192', () => _sendBytes([0x1b, 0x5b, 0x43])),
                  _toolbarKey('Paste', _pasteClipboard),
                  _toolbarKey('/', () => _sendBytes([0x2f])),
                  _toolbarKey('|', () => _sendBytes([0x7c])),
                  _toolbarKey('~', () => _sendBytes([0x7e])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolbarKey(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Material(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 36),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            alignment: Alignment.center,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
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

  Widget _buildComposeBar() {
    return Container(
      color: Colors.grey[900],
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close, color: Colors.grey, size: 20),
              onPressed: _cancelCompose,
              tooltip: 'Cancel',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                controller: _composeController,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Edit command...',
                  hintStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  filled: true,
                  fillColor: Colors.grey[800],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _sendComposedText(),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.send, color: Colors.greenAccent, size: 22),
              onPressed: _sendComposedText,
              tooltip: 'Send',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Live listening overlay (shown while recording)
  // ---------------------------------------------------------------------------

  Widget _buildListeningOverlay() {
    return Positioned(
      bottom: _toolbarVisible ? 120 : 80,
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
    final showMicFab = _speechAvailable &&
        _session.state == SessionState.connected &&
        !_composeVisible;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _onBackPressed()) {
          if (mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
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
            IconButton(
              icon: Icon(
                _toolbarVisible ? Icons.keyboard_hide : Icons.keyboard_command_key,
              ),
              tooltip: 'Terminal keys',
              onPressed: () => setState(() => _toolbarVisible = !_toolbarVisible),
            ),
          ],
        ),
        body: Stack(
          children: [
            // Main content — terminal + toolbar never shift
            Column(
              children: [
                _buildStatusBar(),
                Expanded(
                  child: TerminalView(
                    _terminal,
                    autofocus: !_composeVisible,
                  ),
                ),
                if (_toolbarVisible) _buildToolbar(),
              ],
            ),
            // Compose bar floats above keyboard
            if (_composeVisible)
              Positioned(
                left: 0,
                right: 0,
                bottom: MediaQuery.of(context).viewInsets.bottom,
                child: _buildComposeBar(),
              ),
            // Live transcript overlay while listening
            if (_isListening) _buildListeningOverlay(),
            // Floating mic button
            if (showMicFab)
              Positioned(
                right: 16,
                bottom: (_toolbarVisible ? 100 : 24) +
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
