import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

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
      SessionState.disconnected => (
        isApplePlatform ? CupertinoIcons.link : Icons.link_off,
        'Disconnected',
        c.statusNeutral,
      ),
      SessionState.connecting => (
        isApplePlatform ? CupertinoIcons.arrow_2_circlepath : Icons.sync,
        'Connecting...',
        c.statusConnecting,
      ),
      SessionState.waitingForPeer => (
        isApplePlatform ? CupertinoIcons.clock : Icons.hourglass_empty,
        'Waiting for host...',
        c.statusConnecting,
      ),
      SessionState.handshaking => (
        isApplePlatform ? CupertinoIcons.hand_raised : Icons.handshake,
        'Key exchange...',
        c.statusWarning,
      ),
      SessionState.awaitingConfirm => (
        isApplePlatform ? CupertinoIcons.checkmark_shield : Icons.handshake,
        'Verifying...',
        c.statusWarning,
      ),
      SessionState.connected => (
        isApplePlatform ? CupertinoIcons.lock_fill : Icons.lock,
        'Connected (E2E encrypted)',
        c.statusConnected,
      ),
      SessionState.reconnecting => (
        isApplePlatform ? CupertinoIcons.arrow_2_circlepath : Icons.sync,
        'Reconnecting...',
        c.statusConnecting,
      ),
      SessionState.error => (
        isApplePlatform ? CupertinoIcons.exclamationmark_circle : Icons.error,
        ts.error ?? 'Error',
        c.statusError,
      ),
    };

    final showReconnect =
        ts.sessionState == SessionState.error ||
        ts.sessionState == SessionState.disconnected;
    final showInfo = ts.sessionState == SessionState.connected;

    void reconnect() =>
        ref.read(terminalSessionProvider(pairing).notifier).connect();

    void showSessionInfo() => _showSessionInfoSheet(context, ref, c);

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
              child: Text(
                label,
                style: TextStyle(color: color, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (ts.toolName != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  ts.toolName!,
                  style: TextStyle(color: c.textTertiary, fontSize: 12),
                ),
              ),
            if (showInfo)
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                onPressed: showSessionInfo,
                child: Icon(
                  CupertinoIcons.info_circle,
                  size: 16,
                  color: c.textTertiary,
                ),
              ),
            if (showReconnect)
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                onPressed: reconnect,
                child: Icon(
                  CupertinoIcons.refresh,
                  size: 16,
                  color: c.textSecondary,
                ),
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
            child: Text(
              label,
              style: TextStyle(color: color, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (ts.toolName != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                ts.toolName!,
                style: TextStyle(color: c.textTertiary, fontSize: 12),
              ),
            ),
          if (showInfo)
            GestureDetector(
              onTap: showSessionInfo,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.info_outline,
                  size: 16,
                  color: c.textTertiary,
                ),
              ),
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

  void _showSessionInfoSheet(
    BuildContext context,
    WidgetRef ref,
    FarwatchColors c,
  ) {
    final notifier = ref.read(terminalSessionProvider(pairing).notifier);
    final session = notifier.session;
    final connectedAt = session.connectedAt;
    final fingerprint = session.localFingerprint;
    final hostFingerprint = pairing.expectedFingerprint;

    final rows = <(String, String, bool)>[
      ('Session ID', pairing.sessionId, true),
      ('Relay', pairing.relayUrl, false),
      if (connectedAt != null)
        ('Connected', timeago.format(connectedAt), false),
      if (fingerprint != null) ('Your fingerprint', fingerprint, true),
      if (hostFingerprint != null) ('Host fingerprint', hostFingerprint, true),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: c.surfacePrimary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.textTertiary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Session Info',
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              for (final (label, value, copyable) in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 120,
                        child: Text(
                          label,
                          style: TextStyle(color: c.textTertiary, fontSize: 13),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: copyable
                              ? () {
                                  Clipboard.setData(ClipboardData(text: value));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Copied $label'),
                                      duration: const Duration(seconds: 1),
                                    ),
                                  );
                                }
                              : null,
                          child: Text(
                            value,
                            style: TextStyle(
                              color: c.textSecondary,
                              fontSize: 13,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
