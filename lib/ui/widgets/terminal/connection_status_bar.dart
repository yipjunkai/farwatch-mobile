import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/pairing.dart';
import '../../../providers/terminal_session_provider.dart';
import '../../../relay/session.dart';
import '../../../theme/farwatch_colors.dart';
import '../../adaptive.dart';

/// Connection status strip shown at the top of the terminal screen.
class ConnectionStatusBar extends ConsumerWidget {
  final PairingUri pairing;

  const ConnectionStatusBar({super.key, required this.pairing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ts = ref.watch(terminalSessionProvider(pairing));
    final c = context.colors;

    final (icon, label, color) = switch (ts.sessionState) {
      SessionState.disconnected    => (isApplePlatform ? CupertinoIcons.link : Icons.link_off, 'Disconnected', c.statusNeutral),
      SessionState.connecting      => (isApplePlatform ? CupertinoIcons.arrow_2_circlepath : Icons.sync, 'Connecting...', c.statusConnecting),
      SessionState.waitingForPeer  => (isApplePlatform ? CupertinoIcons.clock : Icons.hourglass_empty, 'Waiting for host...', c.statusConnecting),
      SessionState.handshaking     => (isApplePlatform ? CupertinoIcons.hand_raised : Icons.handshake, 'Key exchange...', c.statusWarning),
      SessionState.awaitingConfirm => (isApplePlatform ? CupertinoIcons.checkmark_shield : Icons.handshake, 'Verifying...', c.statusWarning),
      SessionState.connected       => (isApplePlatform ? CupertinoIcons.lock_fill : Icons.lock, 'Connected (E2E encrypted)', c.statusConnected),
      SessionState.reconnecting    => (isApplePlatform ? CupertinoIcons.arrow_2_circlepath : Icons.sync, 'Reconnecting...', c.statusConnecting),
      SessionState.error           => (isApplePlatform ? CupertinoIcons.exclamationmark_circle : Icons.error, ts.error ?? 'Error', c.statusError),
    };

    final showReconnect = ts.sessionState == SessionState.error ||
        ts.sessionState == SessionState.disconnected;

    void reconnect() =>
        ref.read(terminalSessionProvider(pairing).notifier).connect();

    if (isApplePlatform) {
      return GlassContainer(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        borderRadius: 0,
        color: c.statusBarSurface,
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
                    style: TextStyle(color: c.textTertiary, fontSize: 12)),
              ),
            if (showReconnect)
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                onPressed: reconnect,
                child: Icon(CupertinoIcons.refresh,
                    size: 16, color: c.textSecondary),
              ),
          ],
        ),
      );
    }

    return Container(
      color: c.surfacePrimary,
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
                  style: TextStyle(color: c.textTertiary, fontSize: 12)),
            ),
          if (showReconnect)
            GestureDetector(
              onTap: reconnect,
              child: Icon(Icons.refresh, size: 16, color: c.textSecondary),
            ),
        ],
      ),
    );
  }
}
