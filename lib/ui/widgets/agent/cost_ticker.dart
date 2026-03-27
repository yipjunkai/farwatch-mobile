import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/agent_state_provider.dart';
import '../../../theme/farwatch_colors.dart';

/// Displays session cost and token usage in a compact bar.
class CostTicker extends ConsumerWidget {
  const CostTicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agent = ref.watch(agentStateProvider);
    final c = context.colors;
    if (agent.costUsd == 0.0 && agent.inputTokens == 0) {
      return const SizedBox.shrink();
    }

    return Container(
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
              style: TextStyle(color: c.textSecondary, fontSize: 12, fontFamily: 'monospace')),
          const SizedBox(width: 12),
          Icon(Icons.arrow_downward, color: c.costIcon, size: 12),
          const SizedBox(width: 3),
          Text(_fmt(agent.inputTokens), style: TextStyle(color: c.textTertiary, fontSize: 11)),
          const SizedBox(width: 8),
          Icon(Icons.arrow_upward, color: c.costIcon, size: 12),
          const SizedBox(width: 3),
          Text(_fmt(agent.outputTokens), style: TextStyle(color: c.textTertiary, fontSize: 11)),
        ],
      ),
    );
  }

  static String _fmt(int tokens) {
    if (tokens >= 1000000) return '${(tokens / 1000000).toStringAsFixed(1)}M';
    if (tokens >= 1000) return '${(tokens / 1000).toStringAsFixed(1)}K';
    return tokens.toString();
  }
}
