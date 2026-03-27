import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/pairing.dart';
import '../../../models/agent_message.dart';
import '../../../providers/agent_state_provider.dart';
import '../../../providers/terminal_session_provider.dart';
import '../../adaptive.dart';

/// Permission request card with approve/deny buttons.
class PermissionCard extends ConsumerWidget {
  final AgentMessage message;
  final PairingUri pairing;

  const PermissionCard({
    super.key,
    required this.message,
    required this.pairing,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agent = ref.watch(agentStateProvider);
    final permId = message.toolId ?? '';
    final resolved = agent.pendingPermissions[permId];
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
            Row(children: [
              Icon(
                isPending ? Icons.security : Icons.check_circle_outline,
                color: isPending ? Colors.amber[300] : Colors.grey[500],
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                message.toolName ?? 'Tool',
                style: TextStyle(
                  color: isPending ? Colors.amber[200] : Colors.grey[500],
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              if (!isPending) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: resolved == 'allow'
                        ? Colors.green.withValues(alpha: 0.2)
                        : Colors.red.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    resolved == 'allow' ? 'Allowed' : 'Denied',
                    style: TextStyle(
                      color: resolved == 'allow'
                          ? Colors.green[300]
                          : Colors.red[300],
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ]),
            const SizedBox(height: 6),
            Text(
              message.text,
              style: TextStyle(
                  color: isPending ? Colors.white : Colors.grey[500],
                  fontSize: 13),
            ),
            if (message.toolInput != null &&
                message.toolInput!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                message.toolInput!.length > 150
                    ? '${message.toolInput!.substring(0, 150)}...'
                    : message.toolInput!,
                style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 11,
                    fontFamily: 'monospace'),
              ),
            ],
            if (isPending) ...[
              const SizedBox(height: 10),
              _PermissionButtons(permId: permId, pairing: pairing),
            ],
          ],
        ),
      ),
    );
  }
}

class _PermissionButtons extends ConsumerWidget {
  final String permId;
  final PairingUri pairing;

  const _PermissionButtons({required this.permId, required this.pairing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionNotifier =
        ref.read(terminalSessionProvider(pairing).notifier);

    void deny() {
      HapticFeedback.mediumImpact();
      sessionNotifier.sendDenyToolUse(permId);
      ref.read(agentStateProvider.notifier).resolvePermission(permId, 'deny');
    }

    void allow() {
      HapticFeedback.mediumImpact();
      sessionNotifier.sendApproveToolUse(permId);
      ref
          .read(agentStateProvider.notifier)
          .resolvePermission(permId, 'allow');
    }

    if (isApplePlatform) {
      return Row(children: [
        Expanded(
          child: CupertinoButton(
            padding: const EdgeInsets.symmetric(vertical: 8),
            color: Colors.red.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
            onPressed: deny,
            child: Text('Deny',
                style: TextStyle(color: Colors.red[300], fontSize: 13)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: CupertinoButton(
            padding: const EdgeInsets.symmetric(vertical: 8),
            color: Colors.green.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
            onPressed: allow,
            child: Text('Allow',
                style: TextStyle(color: Colors.green[200], fontSize: 13)),
          ),
        ),
      ]);
    }

    return Row(children: [
      Expanded(
        child: SizedBox(
          height: 36,
          child: OutlinedButton(
            onPressed: deny,
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
            onPressed: allow,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.withValues(alpha: 0.3),
              foregroundColor: Colors.green[200],
              padding: EdgeInsets.zero,
            ),
            child: const Text('Allow', style: TextStyle(fontSize: 13)),
          ),
        ),
      ),
    ]);
  }
}
