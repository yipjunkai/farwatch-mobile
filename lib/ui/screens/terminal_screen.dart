import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';

import '../../core/pairing.dart';
import '../../core/protocol.dart';
import '../../relay/session.dart';
import 'scan_screen.dart';

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

    _outputSub = _session.output.listen((bytes) {
      _terminal.write(utf8.decode(bytes, allowMalformed: true));
    });

    _eventSub = _session.events.listen((msg) {
      switch (msg) {
        case SessionEnded(exitCode: final code):
          _showSnackBar('Session ended (exit code: $code)');
        case VersionNotice(minimumVersion: final v):
          _showSnackBar('Minimum version required: $v');
        default:
          break;
      }
    });

    _session.connect();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
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
        debugPrint('[lifecycle] app backgrounded, pausing heartbeat');
        _session.pauseHeartbeat();

      case AppLifecycleState.resumed:
        debugPrint('[lifecycle] app resumed, checking connection');
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
    _session.dispose();
    super.dispose();
  }

  void _close() async {
    if (await _onBackPressed()) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ScanScreen()),
        );
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _onBackPressed()) {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const ScanScreen()),
            );
          }
        }
      },
      child: Scaffold(
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
        body: Column(
          children: [
            _buildStatusBar(),
            Expanded(
              child: TerminalView(
                _terminal,
                autofocus: true,
              ),
            ),
            if (_toolbarVisible) _buildToolbar(),
          ],
        ),
      ),
    );
  }
}
