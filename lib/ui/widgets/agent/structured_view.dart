import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/pairing.dart';
import '../../../providers/agent_state_provider.dart';
import '../../../providers/terminal_session_provider.dart';
import '../../../theme/farwatch_colors.dart';
import '../../adaptive.dart';
import 'agent_message_card.dart';
import 'cost_ticker.dart';
import 'prompt_bar.dart';
import 'todo_list.dart';
import 'typing_indicator.dart';

/// The structured agent view: cost ticker, todos, message list, prompt bar.
///
/// Includes messenger-style scroll behavior:
///  - Auto-scrolls to bottom on new messages (when already near bottom)
///  - Shows a scroll-to-bottom FAB when scrolled up
///  - Typing indicator when agent is preparing a response
class StructuredView extends ConsumerStatefulWidget {
  final PairingUri pairing;
  const StructuredView({super.key, required this.pairing});

  @override
  ConsumerState<StructuredView> createState() => _StructuredViewState();
}

class _StructuredViewState extends ConsumerState<StructuredView> {
  final _scrollController = ScrollController();
  bool _showScrollFab = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final atBottom = _scrollController.position.maxScrollExtent -
            _scrollController.offset <
        100;
    if (_showScrollFab == atBottom) {
      setState(() => _showScrollFab = !atBottom);
    }
  }

  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      if (animate) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final agent = ref.watch(agentStateProvider);
    final c = context.colors;

    // Auto-scroll when new messages arrive (only if we're near the bottom).
    if (agent.messages.isNotEmpty && !_showScrollFab) {
      _scrollToBottom();
    }

    // Total item count = messages + optional typing indicator.
    final showTyping = agent.agentTyping;
    final itemCount = agent.messages.length + (showTyping ? 1 : 0);

    return Column(
      children: [
        const CostTicker(),
        // Sticky busy banner
        if (agent.agentBusy) _AgentBusyBanner(colors: c),
        const AgentTodoList(),
        Expanded(
          child: Stack(
            children: [
              agent.messages.isEmpty
                  ? _EmptyAgentState(pairing: widget.pairing)
                  : ListView.builder(
                      controller: _scrollController,
                      physics: adaptiveScrollPhysics,
                      padding: const EdgeInsets.all(12),
                      itemCount: itemCount,
                      itemBuilder: (context, index) {
                        // Last item is the typing indicator.
                        if (showTyping && index == agent.messages.length) {
                          return const TypingIndicator();
                        }
                        return AgentMessageCard(
                          message: agent.messages[index],
                          pairing: widget.pairing,
                        );
                      },
                    ),
              // Scroll-to-bottom FAB
              if (_showScrollFab)
                Positioned(
                  right: 12,
                  bottom: 8,
                  child: _ScrollToBottomButton(
                    onPressed: () => _scrollToBottom(),
                    colors: c,
                  ),
                ),
            ],
          ),
        ),
        PromptBar(pairing: widget.pairing),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Scroll-to-bottom button
// ---------------------------------------------------------------------------

class _ScrollToBottomButton extends StatelessWidget {
  final VoidCallback onPressed;
  final FarwatchColors colors;
  const _ScrollToBottomButton(
      {required this.onPressed, required this.colors});

  @override
  Widget build(BuildContext context) {
    if (isApplePlatform) {
      return CupertinoButton(
        padding: const EdgeInsets.all(8),
        color: colors.glassSurface,
        borderRadius: BorderRadius.circular(20),
        onPressed: onPressed,
        child: Icon(CupertinoIcons.chevron_down,
            size: 18, color: colors.textSecondary),
      );
    }
    return FloatingActionButton.small(
      onPressed: onPressed,
      backgroundColor: colors.surfaceSecondary,
      foregroundColor: colors.textSecondary,
      elevation: 2,
      child: const Icon(Icons.keyboard_arrow_down, size: 22),
    );
  }
}

// ---------------------------------------------------------------------------
// Busy banner — thin animated bar while agent is working
// ---------------------------------------------------------------------------

class _AgentBusyBanner extends StatelessWidget {
  final FarwatchColors colors;
  const _AgentBusyBanner({required this.colors});

  @override
  Widget build(BuildContext context) {
    // LinearProgressIndicator with value: null is already self-animating.
    return SizedBox(
      height: 2,
      child: LinearProgressIndicator(
        value: null,
        backgroundColor: colors.surfaceSecondary,
        color: colors.accent,
        minHeight: 2,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyAgentState extends ConsumerWidget {
  final PairingUri pairing;
  const _EmptyAgentState({required this.pairing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ts = ref.read(terminalSessionProvider(pairing));
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, color: c.sendActive, size: 40),
            const SizedBox(height: 16),
            Text(
              'Connected to ${ts.toolName ?? "agent"}',
              style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'Type a prompt below or use the desktop terminal.\n'
              'Activity will appear here as the agent works.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: c.textTertiary, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 16),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: c.infoSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: c.infoBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline, color: c.infoAccent, size: 14),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Both devices can type at the same time. '
                      'Avoid sending while the desktop is typing.',
                      style: TextStyle(color: c.infoAccent, fontSize: 11),
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
