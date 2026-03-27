import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/pairing.dart';
import '../../../providers/agent_state_provider.dart';
import '../../../providers/terminal_session_provider.dart';
import 'agent_message_card.dart';
import 'cost_ticker.dart';
import 'prompt_bar.dart';
import 'todo_list.dart';

/// The structured agent view: cost ticker, todos, message list, prompt bar.
class StructuredView extends ConsumerStatefulWidget {
  final PairingUri pairing;

  const StructuredView({super.key, required this.pairing});

  @override
  ConsumerState<StructuredView> createState() => _StructuredViewState();
}

class _StructuredViewState extends ConsumerState<StructuredView> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final agent = ref.watch(agentStateProvider);

    // Auto-scroll when messages change.
    if (agent.messages.isNotEmpty) _scrollToBottom();

    return Column(
      children: [
        const CostTicker(),
        const AgentTodoList(),
        Expanded(
          child: agent.messages.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: agent.messages.length,
                  itemBuilder: (context, index) => AgentMessageCard(
                    message: agent.messages[index],
                    pairing: widget.pairing,
                  ),
                ),
        ),
        PromptBar(pairing: widget.pairing),
      ],
    );
  }

  Widget _buildEmptyState() {
    final ts = ref.read(terminalSessionProvider(widget.pairing));
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, color: Colors.cyan[300], size: 40),
            const SizedBox(height: 16),
            Text(
              'Connected to ${ts.toolName ?? "agent"}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'Type a prompt below or use the desktop terminal.\n'
              'Activity will appear here as the agent works.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.grey[500], fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 16),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.amber[300], size: 14),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Both devices can type at the same time. '
                      'Avoid sending while the desktop is typing.',
                      style: TextStyle(
                          color: Colors.amber[300], fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
