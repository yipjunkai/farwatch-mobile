import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Future: reconnect on resume, pause heartbeats on background
  }

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
    await _session.disconnect();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ScanScreen()),
      );
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
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        ],
      ),
    );
  }
}
