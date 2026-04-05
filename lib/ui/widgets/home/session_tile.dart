import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/session_history.dart';
import '../../../theme/farwatch_colors.dart';
import '../../adaptive.dart';

/// A single session row in the history list.
/// Renders platform-adaptive styling internally.
class SessionTile extends StatelessWidget {
  final SessionRecord record;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const SessionTile({
    super.key,
    required this.record,
    required this.onTap,
    required this.onDelete,
  });

  static IconData toolIcon(String? toolName) {
    if (toolName == null) return Icons.terminal;
    final name = toolName.toLowerCase();
    if (name.contains('claude')) return Icons.auto_awesome;
    if (name.contains('copilot')) return Icons.smart_toy;
    if (name.contains('gemini')) return Icons.diamond;
    if (name.contains('aider')) return Icons.code;
    if (name.contains('goose')) return Icons.flight;
    if (name.contains('opencode')) return Icons.developer_board;
    return Icons.terminal;
  }

  @override
  Widget build(BuildContext context) {
    if (isApplePlatform) return _buildCupertino(context);
    return _buildMaterial(context);
  }

  Widget _buildMaterial(BuildContext context) {
    final c = context.colors;
    final endIcon = switch (record.endReason) {
      SessionEndReason.unknown => Icons.circle,
      SessionEndReason.userDisconnected => Icons.logout,
      SessionEndReason.hostEnded => Icons.stop_circle_outlined,
      SessionEndReason.connectionLost => Icons.wifi_off,
    };

    final endColor = switch (record.endReason) {
      SessionEndReason.unknown => c.statusNeutral,
      SessionEndReason.userDisconnected => c.statusNeutral,
      SessionEndReason.hostEnded => c.sessionHostEnded,
      SessionEndReason.connectionLost => c.sessionLost,
    };

    final icon = toolIcon(record.toolName);
    final ago = timeago.format(record.lastActiveAt);

    return Dismissible(
      key: Key(record.sessionId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: c.destructive,
        child: Icon(Icons.delete, color: c.destructiveOnSurface),
      ),
      onDismissed: (_) {
        HapticFeedback.mediumImpact();
        onDelete();
      },
      child: ListTile(
        leading: Icon(icon, color: c.accent, size: 28),
        title: Text(
          record.displayName,
          style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          ago,
          style: TextStyle(color: c.textTertiary, fontSize: 12),
        ),
        trailing: Icon(endIcon, size: 14, color: endColor),
        onTap: onTap,
      ),
    );
  }

  Widget _buildCupertino(BuildContext context) {
    final c = context.colors;
    final endIcon = switch (record.endReason) {
      SessionEndReason.unknown => CupertinoIcons.circle,
      SessionEndReason.userDisconnected => CupertinoIcons.square_arrow_right,
      SessionEndReason.hostEnded => CupertinoIcons.stop_circle,
      SessionEndReason.connectionLost => CupertinoIcons.wifi_slash,
    };

    final endColor = switch (record.endReason) {
      SessionEndReason.unknown => c.statusNeutral,
      SessionEndReason.userDisconnected => c.statusNeutral,
      SessionEndReason.hostEnded => c.sessionHostEnded,
      SessionEndReason.connectionLost => c.sessionLost,
    };

    final icon = toolIcon(record.toolName);
    final ago = timeago.format(record.lastActiveAt);

    return Dismissible(
      key: Key(record.sessionId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: c.destructive,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(CupertinoIcons.delete, color: c.destructiveOnSurface),
      ),
      onDismissed: (_) {
        HapticFeedback.mediumImpact();
        onDelete();
      },
      child: GlassContainer(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: onTap,
          child: Row(
            children: [
              Icon(icon, color: c.accent, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.displayName,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ago,
                      style: TextStyle(color: c.textTertiary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(endIcon, size: 14, color: endColor),
              const SizedBox(width: 4),
              Icon(
                CupertinoIcons.chevron_right,
                size: 16,
                color: c.statusNeutral,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
