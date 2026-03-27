import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/agent_state_provider.dart';

/// Displays session cost and token usage in a compact bar.
class CostTicker extends ConsumerWidget {
  const CostTicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agent = ref.watch(agentStateProvider);
    if (agent.costUsd == 0.0 && agent.inputTokens == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.08),
        border: Border(
            bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.15))),
      ),
      child: Row(
        children: [
          Icon(Icons.toll, color: Colors.grey[600], size: 14),
          const SizedBox(width: 6),
          Text('\$${agent.costUsd.toStringAsFixed(4)}',
              style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                  fontFamily: 'monospace')),
          const SizedBox(width: 12),
          Icon(Icons.arrow_downward, color: Colors.grey[600], size: 12),
          const SizedBox(width: 3),
          Text(_formatTokens(agent.inputTokens),
              style: TextStyle(color: Colors.grey[500], fontSize: 11)),
          const SizedBox(width: 8),
          Icon(Icons.arrow_upward, color: Colors.grey[600], size: 12),
          const SizedBox(width: 3),
          Text(_formatTokens(agent.outputTokens),
              style: TextStyle(color: Colors.grey[500], fontSize: 11)),
        ],
      ),
    );
  }

  static String _formatTokens(int tokens) {
    if (tokens >= 1000000) {
      return '${(tokens / 1000000).toStringAsFixed(1)}M';
    }
    if (tokens >= 1000) return '${(tokens / 1000).toStringAsFixed(1)}K';
    return tokens.toString();
  }
}
