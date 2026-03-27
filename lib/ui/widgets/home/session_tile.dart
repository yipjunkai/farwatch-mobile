import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/session_history.dart';
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
    final endIcon = switch (record.endReason) {
      SessionEndReason.unknown => Icons.circle,
      SessionEndReason.userDisconnected => Icons.logout,
      SessionEndReason.hostEnded => Icons.stop_circle_outlined,
      SessionEndReason.connectionLost => Icons.wifi_off,
    };

    final endColor = switch (record.endReason) {
      SessionEndReason.unknown => Colors.grey,
      SessionEndReason.userDisconnected => Colors.grey,
      SessionEndReason.hostEnded => Colors.orange,
      SessionEndReason.connectionLost => Colors.red,
    };

    final icon = toolIcon(record.toolName);
    final ago = timeago.format(record.lastActiveAt);

    return Dismissible(
      key: Key(record.sessionId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: Colors.red[900],
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: ListTile(
        leading: Icon(icon, color: Colors.teal, size: 28),
        title: Text(
          record.displayName,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w500),
        ),
        subtitle:
            Text(ago, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        trailing: Icon(endIcon, size: 14, color: endColor),
        onTap: onTap,
      ),
    );
  }

  Widget _buildCupertino(BuildContext context) {
    final endIcon = switch (record.endReason) {
      SessionEndReason.unknown => CupertinoIcons.circle,
      SessionEndReason.userDisconnected => CupertinoIcons.square_arrow_right,
      SessionEndReason.hostEnded => CupertinoIcons.stop_circle,
      SessionEndReason.connectionLost => CupertinoIcons.wifi_slash,
    };

    final endColor = switch (record.endReason) {
      SessionEndReason.unknown => Colors.grey,
      SessionEndReason.userDisconnected => Colors.grey,
      SessionEndReason.hostEnded => Colors.orange,
      SessionEndReason.connectionLost => Colors.red,
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
          color: CupertinoColors.destructiveRed,
          borderRadius: BorderRadius.circular(10),
        ),
        child:
            const Icon(CupertinoIcons.delete, color: CupertinoColors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: GlassContainer(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: onTap,
          child: Row(
            children: [
              Icon(icon, color: CupertinoColors.systemTeal, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.displayName,
                      style: const TextStyle(
                        color: CupertinoColors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(ago,
                        style:
                            TextStyle(color: Colors.grey[500], fontSize: 12)),
                  ],
                ),
              ),
              Icon(endIcon, size: 14, color: endColor),
              const SizedBox(width: 4),
              const Icon(CupertinoIcons.chevron_right,
                  size: 16, color: CupertinoColors.systemGrey),
            ],
          ),
        ),
      ),
    );
  }
}
