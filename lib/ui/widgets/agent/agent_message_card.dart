import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/pairing.dart';
import '../../../models/agent_message.dart';
import '../../../theme/farwatch_colors.dart';
import 'permission_card.dart';
import 'question_card.dart';
import 'markdown_text.dart';
import 'tool_cards/smart_tool_card.dart';

/// Renders a single [AgentMessage] as the appropriate card type.
///
/// Chat-bubble layout:
///  - User prompts → right-aligned colored bubble
///  - Agent text → left-aligned with markdown rendering
///  - Tool cards, permissions, questions → full-width centered cards
///  - Turn markers → subtle timestamp dividers
///
/// Long-press on any copyable card shows a context menu with Copy action.
class AgentMessageCard extends StatelessWidget {
  final AgentMessage message;
  final PairingUri pairing;

  const AgentMessageCard({
    super.key,
    required this.message,
    required this.pairing,
  });

  /// Whether this message type has text worth copying.
  bool get _isCopyable => switch (message.type) {
        AgentMessageType.text ||
        AgentMessageType.userPrompt ||
        AgentMessageType.thinking ||
        AgentMessageType.toolResult ||
        AgentMessageType.toolError ||
        AgentMessageType.system => true,
        _ => false,
      };

  /// The text to copy for this message.
  String get _copyText => switch (message.type) {
        AgentMessageType.toolCall => message.toolResult ?? message.toolInput ?? message.text,
        _ => message.text,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final child = switch (message.type) {
      AgentMessageType.system => _SystemCard(text: message.text, colors: c),
      AgentMessageType.userPrompt => _UserBubble(text: message.text, colors: c),
      AgentMessageType.text => _TextCard(text: message.text, colors: c),
      AgentMessageType.thinking => _ThinkingCard(text: message.text, colors: c),
      AgentMessageType.toolCall => SmartToolCard(message: message),
      AgentMessageType.toolResult => _ResultCard(text: message.text, colors: c),
      AgentMessageType.toolError => _ErrorCard(text: message.text, colors: c),
      AgentMessageType.turnMarker => _TurnMarker(text: message.text, colors: c),
      AgentMessageType.permissionRequest =>
        PermissionCard(message: message, pairing: pairing),
      AgentMessageType.questionRequest =>
        QuestionCard(message: message, pairing: pairing),
    };

    if (!_isCopyable && message.type != AgentMessageType.toolCall) {
      return child;
    }

    return GestureDetector(
      onLongPress: () {
        HapticFeedback.mediumImpact();
        _showCopyMenu(context, c);
      },
      child: child,
    );
  }

  void _showCopyMenu(BuildContext context, FarwatchColors c) {
    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          // Dismiss scrim
          Positioned.fill(
            child: GestureDetector(
              onTap: () => entry.remove(),
              child: Container(color: Colors.transparent),
            ),
          ),
          // Menu positioned above the card
          Positioned(
            left: position.dx + size.width / 2 - 50,
            top: (position.dy - 44).clamp(48.0, double.infinity),
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              color: c.surfaceSecondary,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: _copyText));
                  HapticFeedback.lightImpact();
                  entry.remove();
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.copy, size: 16, color: c.textSecondary),
                      const SizedBox(width: 6),
                      Text('Copy',
                          style: TextStyle(
                              color: c.textPrimary, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    overlay.insert(entry);
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
// Agent text — left-aligned bubble with markdown rendering (Phase 3)
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
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: colors.surfaceSecondary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: MarkdownText(text: text),
            ),
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
// Result card — standalone fallback for orphaned results (Phase 3)
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
                    maxLines: _expanded ? 10000 : _collapsedMaxLines,
                    overflow: TextOverflow.ellipsis,
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
