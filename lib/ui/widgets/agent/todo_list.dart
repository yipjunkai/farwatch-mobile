import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/agent_state_provider.dart';
import '../../../theme/farwatch_colors.dart';

/// Task checklist rendered from the agent's todo updates.
class AgentTodoList extends ConsumerWidget {
  const AgentTodoList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agent = ref.watch(agentStateProvider);
    final c = context.colors;
    if (agent.todos.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.only(left: 12, right: 12, top: 8),
      decoration: BoxDecoration(
        color: c.todoSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.todoBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.checklist, color: c.todoHeader, size: 14),
              const SizedBox(width: 6),
              Text('Tasks',
                  style: TextStyle(color: c.todoHeader, fontSize: 12, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text(
                '${agent.todos.where((t) => t.status == "completed").length}/${agent.todos.length}',
                style: TextStyle(color: c.textTertiary, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...agent.todos.map((todo) {
            final isCompleted = todo.status == 'completed';
            final isCancelled = todo.status == 'cancelled';
            final isInProgress = todo.status == 'in_progress';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isCompleted
                        ? Icons.check_circle
                        : isCancelled
                            ? Icons.cancel
                            : isInProgress
                                ? Icons.play_circle_filled
                                : Icons.radio_button_unchecked,
                    color: isCompleted
                        ? c.todoCompleted
                        : isCancelled
                            ? c.todoPending
                            : isInProgress
                                ? c.todoInProgress
                                : c.todoPending,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  if (todo.priority == 'high')
                    Container(
                      width: 6, height: 6,
                      margin: const EdgeInsets.only(top: 4, right: 4),
                      decoration: BoxDecoration(shape: BoxShape.circle, color: c.todoHighPriority),
                    ),
                  Expanded(
                    child: Text(
                      todo.content,
                      style: TextStyle(
                        color: isCompleted || isCancelled ? c.todoPending : c.textSecondary,
                        fontSize: 12,
                        decoration: isCancelled ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
