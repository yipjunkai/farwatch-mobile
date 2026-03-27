import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../theme/farwatch_colors.dart';

/// Renders agent text as rich markdown with themed styling.
///
/// Features:
///  - Inline code with background highlight
///  - Fenced code blocks with monospace font
///  - Bold, italic, links, lists, headers
///  - Themed to match [FarwatchColors]
///
/// Copy functionality is provided per-block via long-press (selectable text).
class MarkdownText extends StatelessWidget {
  final String text;

  const MarkdownText({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    // If the text has no markdown indicators, render as plain selectable text
    // for better performance on streaming deltas.
    if (!_looksLikeMarkdown(text)) {
      return SelectableText(
        text,
        style: TextStyle(color: c.textPrimary, fontSize: 14, height: 1.5),
      );
    }

    return MarkdownBody(
      data: text,
      selectable: true,
      shrinkWrap: true,
      softLineBreak: true,
      styleSheet: _buildStyleSheet(c),
    );
  }

  /// Quick heuristic: does the text contain markdown formatting?
  /// Avoids the cost of full markdown parsing for plain text messages.
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
      // Body text
      p: TextStyle(color: c.textPrimary, fontSize: 14, height: 1.5),

      // Headers
      h1: TextStyle(
          color: c.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          height: 1.4),
      h2: TextStyle(
          color: c.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          height: 1.4),
      h3: TextStyle(
          color: c.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          height: 1.4),
      h4: TextStyle(
          color: c.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.4),

      // Strong (bold) and emphasis (italic)
      strong: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold),
      em: TextStyle(color: c.textPrimary, fontStyle: FontStyle.italic),

      // Inline code
      code: TextStyle(
        color: c.textPrimary,
        backgroundColor: c.codeInlineBackground,
        fontFamily: 'monospace',
        fontSize: 13,
      ),

      // Fenced code blocks
      codeblockDecoration: BoxDecoration(
        color: c.codeBlockBackground,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.codeBlockBorder),
      ),
      codeblockPadding: const EdgeInsets.all(12),

      // Links
      a: TextStyle(color: c.accent, decoration: TextDecoration.underline),

      // Lists
      listBullet: TextStyle(color: c.textSecondary, fontSize: 14),
      listIndent: 20.0,

      // Block quotes
      blockquote: TextStyle(
          color: c.textTertiary, fontStyle: FontStyle.italic, fontSize: 14),
      blockquoteDecoration: BoxDecoration(
        border: Border(left: BorderSide(color: c.surfaceTertiary, width: 3)),
      ),
      blockquotePadding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),

      // Horizontal rule
      horizontalRuleDecoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.surfaceTertiary, width: 1)),
      ),

      // Table
      tableHead: TextStyle(
          color: c.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
      tableBody: TextStyle(color: c.textSecondary, fontSize: 13),
      tableBorder: TableBorder.all(color: c.surfaceTertiary, width: 0.5),
    );
  }
}
