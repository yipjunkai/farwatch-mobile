import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/pairing.dart';
import '../../../providers/terminal_session_provider.dart';
import '../../../relay/session.dart';
import '../../adaptive.dart';

/// Connection status strip shown at the top of the terminal screen.
class ConnectionStatusBar extends ConsumerWidget {
  final PairingUri pairing;

  const ConnectionStatusBar({super.key, required this.pairing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ts = ref.watch(terminalSessionProvider(pairing));

    final (icon, label, color) = switch (ts.sessionState) {
      SessionState.disconnected    => (Icons.link_off, 'Disconnected', Colors.grey),
      SessionState.connecting      => (Icons.sync, 'Connecting...', Colors.orange),
      SessionState.waitingForPeer  => (Icons.hourglass_empty, 'Waiting for host...', Colors.orange),
      SessionState.handshaking     => (Icons.handshake, 'Key exchange...', Colors.amber),
      SessionState.awaitingConfirm => (Icons.handshake, 'Verifying...', Colors.amber),
      SessionState.connected       => (Icons.lock, 'Connected (E2E encrypted)', Colors.green),
      SessionState.reconnecting    => (Icons.sync, 'Reconnecting...', Colors.orange),
      SessionState.error           => (Icons.error, ts.error ?? 'Error', Colors.red),
    };

    final showReconnect = ts.sessionState == SessionState.error ||
        ts.sessionState == SessionState.disconnected;

    void reconnect() =>
        ref.read(terminalSessionProvider(pairing).notifier).connect();

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
                onPressed: reconnect,
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
              onTap: reconnect,
              child: Icon(Icons.refresh, size: 16, color: Colors.grey[400]),
            ),
        ],
      ),
    );
  }
}
