import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/pairing.dart';
import '../../../models/agent_message.dart';
import '../../../theme/farwatch_colors.dart';
import 'permission_card.dart';
import 'question_card.dart';
import 'markdown_text.dart';

/// Renders a single [AgentMessage] as the appropriate card type.
///
/// Chat-bubble layout:
///  - User prompts → right-aligned colored bubble
///  - Agent text → left-aligned with markdown rendering
///  - Tool cards, permissions, questions → full-width centered cards
///  - Turn markers → subtle timestamp dividers
class AgentMessageCard extends StatelessWidget {
  final AgentMessage message;
  final PairingUri pairing;

  const AgentMessageCard({
    super.key,
    required this.message,
    required this.pairing,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return switch (message.type) {
      AgentMessageType.system => _SystemCard(text: message.text, colors: c),
      AgentMessageType.userPrompt => _UserBubble(text: message.text, colors: c),
      AgentMessageType.text => _TextCard(text: message.text, colors: c),
      AgentMessageType.thinking => _ThinkingCard(text: message.text, colors: c),
      AgentMessageType.toolCall => _ToolCallCard(
          name: message.text, input: message.toolInput, colors: c),
      AgentMessageType.toolResult => _ResultCard(text: message.text, colors: c),
      AgentMessageType.toolError => _ErrorCard(text: message.text, colors: c),
      AgentMessageType.turnMarker => _TurnMarker(text: message.text, colors: c),
      AgentMessageType.permissionRequest =>
        PermissionCard(message: message, pairing: pairing),
      AgentMessageType.questionRequest =>
        QuestionCard(message: message, pairing: pairing),
    };
  }
}

// ---------------------------------------------------------------------------
// System card
// ---------------------------------------------------------------------------

class _SystemCard extends StatelessWidget {
  final String text;
  final FarwatchColors colors;
  const _SystemCard({required this.text, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colors.systemSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text,
            style: TextStyle(
                color: colors.textSecondary,
                fontSize: 12,
                fontFamily: 'monospace')),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// User prompt bubble — right-aligned, accent-colored (Phase 2)
// ---------------------------------------------------------------------------

class _UserBubble extends StatelessWidget {
  final String text;
  final FarwatchColors colors;
  const _UserBubble({required this.text, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const SizedBox(width: 48), // left gutter so bubble doesn't span full width
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: colors.userBubble,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Text(
                text,
                style: TextStyle(
                  color: colors.userBubbleText,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Agent text — left-aligned with markdown rendering (Phase 3)
// ---------------------------------------------------------------------------

class _TextCard extends StatelessWidget {
  final String text;
  final FarwatchColors colors;
  const _TextCard({required this.text, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: MarkdownText(text: text),
          ),
          const SizedBox(width: 48), // right gutter
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Thinking card
// ---------------------------------------------------------------------------

class _ThinkingCard extends StatelessWidget {
  final String text;
  final FarwatchColors colors;
  const _ThinkingCard({required this.text, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colors.thinkingSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.thinkingBorder),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.psychology, color: colors.thinkingIcon, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: colors.thinkingAccent,
                    fontSize: 13,
                    fontStyle: FontStyle.italic)),
          ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tool call card
// ---------------------------------------------------------------------------

class _ToolCallCard extends StatelessWidget {
  final String name;
  final String? input;
  final FarwatchColors colors;
  const _ToolCallCard(
      {required this.name, this.input, required this.colors});

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
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.build, color: colors.toolCallAccent, size: 16),
            const SizedBox(width: 6),
            Text(name,
                style: TextStyle(
                    color: colors.toolCallAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ]),
          if (input != null && input!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              input!.length > 200 ? '${input!.substring(0, 200)}...' : input!,
              style: TextStyle(
                  color: colors.textTertiary,
                  fontSize: 11,
                  fontFamily: 'monospace'),
            ),
          ],
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Result card — expandable with copy button (Phase 3)
// ---------------------------------------------------------------------------

class _ResultCard extends StatefulWidget {
  final String text;
  final FarwatchColors colors;
  const _ResultCard({required this.text, required this.colors});

  @override
  State<_ResultCard> createState() => _ResultCardState();
}

class _ResultCardState extends State<_ResultCard> {
  bool _expanded = false;

  static const int _collapsedMaxChars = 300;
  static const int _collapsedMaxLines = 6;

  bool get _isLong => widget.text.length > _collapsedMaxChars;

  String get _displayText {
    if (_expanded || !_isLong) return widget.text;
    return '${widget.text.substring(0, _collapsedMaxChars)}...';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: widget.colors.resultSurface,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with copy button
            Row(
              children: [
                Expanded(
                  child: Text(
                    _displayText,
                    style: TextStyle(
                      color: widget.colors.textTertiary,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                    maxLines: _expanded ? null : _collapsedMaxLines,
                    overflow: _expanded ? null : TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                _CopyButton(text: widget.text, colors: widget.colors),
              ],
            ),
            // Expand/collapse toggle
            if (_isLong) ...[
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Text(
                  _expanded ? 'Show less' : 'Show more',
                  style: TextStyle(
                    color: widget.colors.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error card
// ---------------------------------------------------------------------------

class _ErrorCard extends StatelessWidget {
  final String text;
  final FarwatchColors colors;
  const _ErrorCard({required this.text, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colors.errorSurface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: colors.errorBorder),
        ),
        child: Row(children: [
          Icon(Icons.error_outline, color: colors.statusErrorAccent, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                style:
                    TextStyle(color: colors.statusErrorAccent, fontSize: 12),
                maxLines: 5,
                overflow: TextOverflow.ellipsis),
          ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Turn marker
// ---------------------------------------------------------------------------

class _TurnMarker extends StatelessWidget {
  final String text;
  final FarwatchColors colors;
  const _TurnMarker({required this.text, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Expanded(child: Divider(color: colors.surfaceTertiary)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(text,
              style: TextStyle(
                  color: colors.textPlaceholder, fontSize: 11)),
        ),
        Expanded(child: Divider(color: colors.surfaceTertiary)),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Copy button (reused across cards)
// ---------------------------------------------------------------------------

class _CopyButton extends StatefulWidget {
  final String text;
  final FarwatchColors colors;
  const _CopyButton({required this.text, required this.colors});

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  void _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    HapticFeedback.lightImpact();
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _copy,
      child: Icon(
        _copied ? Icons.check : Icons.copy,
        size: 14,
        color: _copied ? widget.colors.statusConnected : widget.colors.copyButton,
      ),
    );
  }
}
