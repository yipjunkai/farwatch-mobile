import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../theme/farwatch_colors.dart';

/// Renders agent text as rich markdown with themed styling.
///
/// Falls back to plain [SelectableText] if:
///  - Text is short (<10 chars) or has no markdown indicators
///  - [MarkdownBody] throws during build or layout
class MarkdownText extends StatelessWidget {
  final String text;

  const MarkdownText({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final plainStyle = TextStyle(color: c.textPrimary, fontSize: 14, height: 1.5);

    // For short text or text without markdown indicators, use plain text.
    // This is also safer during streaming (partial markdown can break the parser).
    if (text.length < 10 || !_looksLikeMarkdown(text)) {
      return SelectableText(text, style: plainStyle);
    }

    // Wrap in _MarkdownErrorBoundary to catch build/layout errors gracefully.
    return _MarkdownErrorBoundary(
      fallback: SelectableText(text, style: plainStyle),
      child: MarkdownBody(
        data: text,
        selectable: true,
        shrinkWrap: true,
        softLineBreak: true,
        fitContent: true,
        styleSheet: _buildStyleSheet(c),
      ),
    );
  }

  /// Quick heuristic: does the text contain markdown formatting?
  static bool _looksLikeMarkdown(String text) {
    return text.contains('```') ||
        text.contains('**') ||
        text.contains('# ') ||
        text.contains('- ') ||
        text.contains('`') ||
        text.contains('[') ||
        text.contains('> ');
  }

  MarkdownStyleSheet _buildStyleSheet(FarwatchColors c) {
    return MarkdownStyleSheet(
      p: TextStyle(color: c.textPrimary, fontSize: 14, height: 1.5),
      h1: TextStyle(
          color: c.textPrimary, fontSize: 22, fontWeight: FontWeight.bold, height: 1.4),
      h2: TextStyle(
          color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.bold, height: 1.4),
      h3: TextStyle(
          color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w600, height: 1.4),
      h4: TextStyle(
          color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w600, height: 1.4),
      strong: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold),
      em: TextStyle(color: c.textPrimary, fontStyle: FontStyle.italic),
      code: TextStyle(
        color: c.textPrimary,
        backgroundColor: c.codeInlineBackground,
        fontFamily: 'monospace',
        fontSize: 13,
      ),
      codeblockDecoration: BoxDecoration(
        color: c.codeBlockBackground,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.codeBlockBorder),
      ),
      codeblockPadding: const EdgeInsets.all(12),
      a: TextStyle(color: c.accent, decoration: TextDecoration.underline),
      listBullet: TextStyle(color: c.textSecondary, fontSize: 14),
      listIndent: 20.0,
      blockquote: TextStyle(
          color: c.textTertiary, fontStyle: FontStyle.italic, fontSize: 14),
      blockquoteDecoration: BoxDecoration(
        border: Border(left: BorderSide(color: c.surfaceTertiary, width: 3)),
      ),
      blockquotePadding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.surfaceTertiary, width: 1)),
      ),
      tableHead: TextStyle(
          color: c.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
      tableBody: TextStyle(color: c.textSecondary, fontSize: 13),
      tableBorder: TableBorder.all(color: c.surfaceTertiary, width: 0.5),
    );
  }
}

// ---------------------------------------------------------------------------
// Error boundary — catches Flutter framework errors during build/layout
// ---------------------------------------------------------------------------

class _MarkdownErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget fallback;

  const _MarkdownErrorBoundary({required this.child, required this.fallback});

  @override
  State<_MarkdownErrorBoundary> createState() => _MarkdownErrorBoundaryState();
}

class _MarkdownErrorBoundaryState extends State<_MarkdownErrorBoundary> {
  bool _hasError = false;

  @override
  void didUpdateWidget(_MarkdownErrorBoundary oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset error state when text changes so we retry rendering.
    if (oldWidget.child != widget.child) {
      _hasError = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) return widget.fallback;

    // Use ErrorWidget.builder override to catch errors during child build/layout.
    final oldHandler = ErrorWidget.builder;
    ErrorWidget.builder = (details) {
      // Schedule a rebuild to show the fallback on next frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_hasError) {
          setState(() => _hasError = true);
        }
      });
      // Return a zero-size placeholder for this frame.
      return const SizedBox.shrink();
    };

    final result = widget.child;

    // Restore original error handler.
    ErrorWidget.builder = oldHandler;

    return result;
  }
}
