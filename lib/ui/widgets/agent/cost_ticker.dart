import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/agent_state_provider.dart';
import '../../../theme/farwatch_colors.dart';
import '../../adaptive.dart';

/// Displays session cost and token usage in a compact tappable bar.
///
/// Tap opens a detailed cost breakdown bottom sheet.
class CostTicker extends ConsumerWidget {
  const CostTicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agent = ref.watch(agentStateProvider);
    final c = context.colors;
    if (agent.costUsd == 0.0 && agent.inputTokens == 0) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _showCostBreakdown(context, agent, c);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: c.costSurface,
          border: Border(bottom: BorderSide(color: c.costDivider)),
        ),
        child: Row(
          children: [
            Icon(Icons.toll, color: c.costIcon, size: 14),
            const SizedBox(width: 6),
            Text('\$${agent.costUsd.toStringAsFixed(4)}',
                style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 12,
                    fontFamily: 'monospace')),
            const SizedBox(width: 12),
            Icon(Icons.arrow_downward, color: c.costIcon, size: 12),
            const SizedBox(width: 3),
            Text(_fmt(agent.inputTokens),
                style: TextStyle(color: c.textTertiary, fontSize: 11)),
            const SizedBox(width: 8),
            Icon(Icons.arrow_upward, color: c.costIcon, size: 12),
            const SizedBox(width: 3),
            Text(_fmt(agent.outputTokens),
                style: TextStyle(color: c.textTertiary, fontSize: 11)),
            const Spacer(),
            Icon(Icons.expand_more, color: c.textPlaceholder, size: 16),
          ],
        ),
      ),
    );
  }

  static String _fmt(int tokens) {
    if (tokens >= 1000000) {
      return '${(tokens / 1000000).toStringAsFixed(1)}M';
    }
    if (tokens >= 1000) return '${(tokens / 1000).toStringAsFixed(1)}K';
    return tokens.toString();
  }

  void _showCostBreakdown(
      BuildContext context, AgentState agent, FarwatchColors c) {
    if (isApplePlatform) {
      showCupertinoModalPopup<void>(
        context: context,
        builder: (ctx) => _CostSheet(agent: agent, colors: c),
      );
    } else {
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: c.surfacePrimary,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) => _CostSheet(agent: agent, colors: c),
      );
    }
  }
}

class _CostSheet extends StatelessWidget {
  final AgentState agent;
  final FarwatchColors colors;

  const _CostSheet({required this.agent, required this.colors});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isApplePlatform ? colors.glassSurface : colors.surfacePrimary,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.surfaceTertiary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Session Cost Breakdown',
                style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),

            // Total cost — big number
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.costSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    '\$${agent.costUsd.toStringAsFixed(6)}',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Total Session Cost',
                      style: TextStyle(
                          color: colors.textTertiary, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Token breakdown
            _TokenRow(
                label: 'Input Tokens',
                value: agent.inputTokens,
                icon: Icons.arrow_downward,
                color: colors.accent,
                colors: colors),
            const SizedBox(height: 8),
            _TokenRow(
                label: 'Output Tokens',
                value: agent.outputTokens,
                icon: Icons.arrow_upward,
                color: colors.sendActive,
                colors: colors),
            const SizedBox(height: 8),

            // Message count
            Divider(color: colors.costDivider, height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Messages',
                    style: TextStyle(
                        color: colors.textTertiary, fontSize: 13)),
                Text('${agent.messages.length}',
                    style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 13,
                        fontFamily: 'monospace')),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Active Tasks',
                    style: TextStyle(
                        color: colors.textTertiary, fontSize: 13)),
                Text(
                    '${agent.todos.where((t) => t.status == "in_progress" || t.status == "pending").length}',
                    style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 13,
                        fontFamily: 'monospace')),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _TokenRow extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final FarwatchColors colors;

  const _TokenRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(color: colors.textTertiary, fontSize: 13)),
        const Spacer(),
        Text(
          _formatDetailed(value),
          style: TextStyle(
              color: colors.textSecondary,
              fontSize: 13,
              fontFamily: 'monospace'),
        ),
      ],
    );
  }

  static String _formatDetailed(int tokens) {
    if (tokens >= 1000000) {
      return '${(tokens / 1000000).toStringAsFixed(2)}M ($tokens)';
    }
    if (tokens >= 1000) {
      return '${(tokens / 1000).toStringAsFixed(1)}K ($tokens)';
    }
    return tokens.toString();
  }
}
