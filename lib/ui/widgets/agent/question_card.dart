import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/pairing.dart';
import '../../../models/agent_message.dart';
import '../../../providers/agent_state_provider.dart';
import '../../../providers/terminal_session_provider.dart';
import '../../../theme/farwatch_colors.dart';
import '../../adaptive.dart';

/// Renders an `mcp_question` tool call as native mobile selection UI.
///
/// Adapts presentation based on question structure:
///  - Binary (2 options, single-select) → side-by-side buttons
///  - Single-select (3+ options) → radio tile list
///  - Multi-select → checkbox tile list with "Done" button
///  - Free-text fallback → option chips above a text field
class QuestionCard extends ConsumerStatefulWidget {
  final AgentMessage message;
  final PairingUri pairing;

  const QuestionCard({super.key, required this.message, required this.pairing});

  @override
  ConsumerState<QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends ConsumerState<QuestionCard> {
  /// Selected option labels for multi-select mode.
  final Set<String> _selected = {};

  /// Text controller for the free-text / custom answer field.
  final _customController = TextEditingController();

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _submit(List<String> labels) {
    HapticFeedback.mediumImpact();
    final toolId = widget.message.toolId ?? '';

    // Send the answer as a prompt (the response format OpenCode expects).
    final answerText = labels.join(', ');
    ref
        .read(terminalSessionProvider(widget.pairing).notifier)
        .sendAgentPrompt(answerText);

    // Mark the question as resolved in state.
    ref.read(agentStateProvider.notifier).resolveQuestion(toolId, labels);
  }

  @override
  Widget build(BuildContext context) {
    final agent = ref.watch(agentStateProvider);
    final c = context.colors;
    final toolId = widget.message.toolId ?? '';
    final answered = agent.pendingQuestions[toolId];
    final isResolved = answered != null;
    final questionData = widget.message.questionData;

    if (questionData == null || questionData.questions.isEmpty) {
      // Fallback: render as a basic card.
      return _FallbackCard(text: widget.message.text, colors: c);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: GlassContainer(
        padding: const EdgeInsets.all(12),
        color: isResolved ? c.permissionResolvedSurface : c.questionSurface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final q in questionData.questions)
              _buildQuestion(context, q, isResolved, answered, c),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestion(
    BuildContext context,
    QuestionItem question,
    bool isResolved,
    List<String>? answeredLabels,
    FarwatchColors c,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Icon(
              isResolved ? Icons.check_circle_outline : Icons.help_outline,
              color: isResolved ? c.textTertiary : c.questionAccent,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                question.header,
                style: TextStyle(
                  color: isResolved ? c.textTertiary : c.questionAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            if (isResolved && answeredLabels != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: c.allowedBadge,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  answeredLabels.join(', '),
                  style: TextStyle(
                    color: c.approveText,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),

        // Question text
        Text(
          question.question,
          style: TextStyle(
            color: isResolved ? c.textTertiary : c.textPrimary,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 10),

        // Options — choose rendering based on question type.
        if (!isResolved) ...[
          if (question.isBinary)
            _BinaryButtons(
              options: question.options,
              onSelect: (label) => _submit([label]),
              colors: c,
            )
          else if (!question.multiple)
            _SingleSelectList(
              options: question.options,
              onSelect: (label) => _submit([label]),
              colors: c,
            )
          else
            _MultiSelectList(
              options: question.options,
              selected: _selected,
              onToggle: (label) => setState(() {
                _selected.contains(label)
                    ? _selected.remove(label)
                    : _selected.add(label);
              }),
              onDone: () {
                if (_selected.isNotEmpty) _submit(_selected.toList());
              },
              colors: c,
            ),

          // Custom answer field (always available as fallback).
          const SizedBox(height: 8),
          _CustomAnswerField(
            controller: _customController,
            onSubmit: (text) => _submit([text]),
            colors: c,
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Binary (2-option) buttons — side-by-side, like permission Allow/Deny.
// ---------------------------------------------------------------------------

class _BinaryButtons extends StatelessWidget {
  final List<QuestionOption> options;
  final ValueChanged<String> onSelect;
  final FarwatchColors colors;

  const _BinaryButtons({
    required this.options,
    required this.onSelect,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    if (isApplePlatform) {
      return Row(
        children: [
          for (int i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 10),
                color: i == 0
                    ? colors.questionPrimaryButton
                    : colors.questionSecondaryButton,
                borderRadius: BorderRadius.circular(8),
                onPressed: () => onSelect(options[i].label),
                child: Column(
                  children: [
                    Text(
                      options[i].label,
                      style: TextStyle(
                        color: i == 0
                            ? colors.textPrimary
                            : colors.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (options[i].description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        options[i].description,
                        style: TextStyle(
                          color: colors.textTertiary,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      );
    }

    return Row(
      children: [
        for (int i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: options[i].description.isNotEmpty ? 56 : 40,
              child: i == 0
                  ? ElevatedButton(
                      onPressed: () => onSelect(options[i].label),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.questionPrimaryButton,
                        foregroundColor: colors.textPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                      ),
                      child: _ButtonContent(option: options[i], colors: colors),
                    )
                  : OutlinedButton(
                      onPressed: () => onSelect(options[i].label),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.textSecondary,
                        side: BorderSide(color: colors.questionSecondaryButton),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                      ),
                      child: _ButtonContent(option: options[i], colors: colors),
                    ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ButtonContent extends StatelessWidget {
  final QuestionOption option;
  final FarwatchColors colors;
  const _ButtonContent({required this.option, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          option.label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        if (option.description.isNotEmpty)
          Text(
            option.description,
            style: TextStyle(fontSize: 10, color: colors.textTertiary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Single-select — tappable radio-style tile list.
// ---------------------------------------------------------------------------

class _SingleSelectList extends StatelessWidget {
  final List<QuestionOption> options;
  final ValueChanged<String> onSelect;
  final FarwatchColors colors;

  const _SingleSelectList({
    required this.options,
    required this.onSelect,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final option in options)
          _OptionTile(
            option: option,
            trailing: Icon(
              CupertinoIcons.chevron_right,
              size: 14,
              color: colors.textPlaceholder,
            ),
            onTap: () => onSelect(option.label),
            colors: colors,
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Multi-select — checkbox tile list with "Done" button.
// ---------------------------------------------------------------------------

class _MultiSelectList extends StatelessWidget {
  final List<QuestionOption> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final VoidCallback onDone;
  final FarwatchColors colors;

  const _MultiSelectList({
    required this.options,
    required this.selected,
    required this.onToggle,
    required this.onDone,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final option in options)
          _OptionTile(
            option: option,
            trailing: _AdaptiveCheckbox(
              checked: selected.contains(option.label),
              colors: colors,
            ),
            onTap: () => onToggle(option.label),
            colors: colors,
          ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: isApplePlatform
              ? CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  color: selected.isEmpty
                      ? colors.surfaceTertiary
                      : colors.questionPrimaryButton,
                  borderRadius: BorderRadius.circular(8),
                  onPressed: selected.isEmpty ? null : onDone,
                  child: Text(
                    'Done (${selected.length} selected)',
                    style: TextStyle(
                      color: selected.isEmpty
                          ? colors.textPlaceholder
                          : colors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                )
              : ElevatedButton(
                  onPressed: selected.isEmpty ? null : onDone,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.questionPrimaryButton,
                    disabledBackgroundColor: colors.surfaceTertiary,
                    foregroundColor: colors.textPrimary,
                    disabledForegroundColor: colors.textPlaceholder,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text('Done (${selected.length} selected)'),
                ),
        ),
      ],
    );
  }
}

class _AdaptiveCheckbox extends StatelessWidget {
  final bool checked;
  final FarwatchColors colors;
  const _AdaptiveCheckbox({required this.checked, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: checked ? colors.questionAccent : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: checked ? colors.questionAccent : colors.textPlaceholder,
          width: 1.5,
        ),
      ),
      child: checked
          ? Icon(Icons.check, size: 16, color: colors.background)
          : null,
    );
  }
}

// ---------------------------------------------------------------------------
// Shared option tile
// ---------------------------------------------------------------------------

class _OptionTile extends StatelessWidget {
  final QuestionOption option;
  final Widget trailing;
  final VoidCallback onTap;
  final FarwatchColors colors;

  const _OptionTile({
    required this.option,
    required this.trailing,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colors.questionOptionSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.questionOptionBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.label,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (option.description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      option.description,
                      style: TextStyle(
                        color: colors.textTertiary,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Custom answer text field (always available below options)
// ---------------------------------------------------------------------------

class _CustomAnswerField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSubmit;
  final FarwatchColors colors;

  const _CustomAnswerField({
    required this.controller,
    required this.onSubmit,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: isApplePlatform
              ? CupertinoTextField(
                  controller: controller,
                  placeholder: 'Type a custom answer...',
                  placeholderStyle: TextStyle(
                    color: colors.textPlaceholder,
                    fontSize: 12,
                  ),
                  style: TextStyle(color: colors.textPrimary, fontSize: 13),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colors.inputBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (text) {
                    if (text.trim().isNotEmpty) onSubmit(text.trim());
                  },
                )
              : TextField(
                  controller: controller,
                  style: TextStyle(color: colors.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Type a custom answer...',
                    hintStyle: TextStyle(
                      color: colors.textPlaceholder,
                      fontSize: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: colors.surfaceTertiary),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: colors.surfaceTertiary),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    isDense: true,
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (text) {
                    if (text.trim().isNotEmpty) onSubmit(text.trim());
                  },
                ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 32,
          height: 32,
          child: isApplePlatform
              ? CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  color: colors.questionAccent,
                  borderRadius: BorderRadius.circular(16),
                  onPressed: () {
                    final text = controller.text.trim();
                    if (text.isNotEmpty) onSubmit(text);
                  },
                  child: Icon(
                    CupertinoIcons.arrow_up,
                    size: 16,
                    color: colors.background,
                  ),
                )
              : Material(
                  color: colors.questionAccent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () {
                      final text = controller.text.trim();
                      if (text.isNotEmpty) onSubmit(text);
                    },
                    child: Center(
                      child: Icon(
                        Icons.arrow_upward,
                        size: 16,
                        color: colors.background,
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Fallback for malformed question data
// ---------------------------------------------------------------------------

class _FallbackCard extends StatelessWidget {
  final String text;
  final FarwatchColors colors;
  const _FallbackCard({required this.text, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colors.toolCallSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.toolCallBorder),
        ),
        child: Row(
          children: [
            Icon(Icons.help_outline, color: colors.toolCallAccent, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(color: colors.textPrimary, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
