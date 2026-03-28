import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../models/agent_message.dart';
import '../../../../theme/farwatch_colors.dart';
import 'tool_input_parser.dart';
import 'tool_shimmer.dart';

/// Routes a [toolCall] message to a tool-specific smart card based on
/// [AgentMessage.toolName].
///
/// Falls back to a generic tool card for unrecognized tool names.
class SmartToolCard extends StatelessWidget {
  final AgentMessage message;

  const SmartToolCard({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final toolName = message.toolName ?? message.text;
    final input = ToolInputParser(message.toolInput);

    // If the tool is still running, show shimmer loading state.
    if (message.toolRunning) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: _SmartToolWrapper(
          toolName: toolName,
          icon: _iconForTool(toolName),
          colors: c,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _toolHeaderContent(toolName, input, c),
              const SizedBox(height: 8),
              ToolShimmer(
                toolName: toolName,
                startedAt: message.toolStartedAt ?? DateTime.now(),
                colors: c,
              ),
            ],
          ),
        ),
      );
    }

    // Completed tool — render tool-specific card.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: switch (toolName) {
        'mcp_bash' => _BashCard(message: message, input: input, colors: c),
        'mcp_read' => _ReadCard(message: message, input: input, colors: c),
        'mcp_edit' => _EditCard(message: message, input: input, colors: c),
        'mcp_write' => _WriteCard(message: message, input: input, colors: c),
        'mcp_glob' => _GlobCard(message: message, input: input, colors: c),
        'mcp_grep' => _GrepCard(message: message, input: input, colors: c),
        'mcp_webfetch' => _WebFetchCard(message: message, input: input, colors: c),
        _ => _GenericToolCard(message: message, input: input, colors: c),
      },
    );
  }

  static IconData _iconForTool(String name) {
    return switch (name) {
      'mcp_bash' => Icons.terminal,
      'mcp_read' => Icons.description_outlined,
      'mcp_edit' => Icons.edit_note,
      'mcp_write' => Icons.note_add_outlined,
      'mcp_glob' => Icons.folder_open,
      'mcp_grep' => Icons.search,
      'mcp_webfetch' => Icons.language,
      'mcp_task' => Icons.account_tree,
      'mcp_todowrite' => Icons.checklist,
      _ => Icons.build,
    };
  }

  /// Builds the tool-specific header content (before result).
  static Widget _toolHeaderContent(
      String toolName, ToolInputParser input, FarwatchColors c) {
    return switch (toolName) {
      'mcp_bash' => _bashHeader(input, c),
      'mcp_read' => _filePathHeader(input.filePath, 'Read', c),
      'mcp_edit' => _filePathHeader(input.filePath, 'Edit', c),
      'mcp_write' => _filePathHeader(input.filePath, 'Write', c),
      'mcp_glob' => _patternHeader(input.pattern, 'Glob', Icons.folder_open, c),
      'mcp_grep' => _patternHeader(input.pattern, 'Grep', Icons.search, c),
      'mcp_webfetch' => _urlHeader(input.url, c),
      _ => const SizedBox.shrink(),
    };
  }

  static Widget _bashHeader(ToolInputParser input, FarwatchColors c) {
    final cmd = input.command;
    final desc = input.description;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (desc != null && desc.isNotEmpty)
          Text(desc,
              style: TextStyle(color: c.textSecondary, fontSize: 12)),
        if (cmd != null && cmd.isNotEmpty) ...[
          if (desc != null && desc.isNotEmpty) const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: c.codeBlockBackground,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '\$ $cmd',
              style: TextStyle(
                color: c.textPrimary,
                fontFamily: 'monospace',
                fontSize: 12,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        if (input.workdir != null) ...[
          const SizedBox(height: 2),
          Text(
            input.workdir!,
            style: TextStyle(color: c.textPlaceholder, fontSize: 10, fontFamily: 'monospace'),
          ),
        ],
      ],
    );
  }

  static Widget _filePathHeader(
      String? path, String action, FarwatchColors c) {
    if (path == null) return const SizedBox.shrink();
    final fileName = path.split('/').last;
    final dirPath =
        path.contains('/') ? path.substring(0, path.lastIndexOf('/') + 1) : '';
    return Row(children: [
      Icon(Icons.insert_drive_file_outlined,
          size: 14, color: c.toolCallAccent),
      const SizedBox(width: 6),
      Expanded(
        child: Text.rich(
          TextSpan(children: [
            if (dirPath.isNotEmpty)
              TextSpan(
                  text: dirPath,
                  style: TextStyle(
                      color: c.textPlaceholder,
                      fontSize: 12,
                      fontFamily: 'monospace')),
            TextSpan(
                text: fileName,
                style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace')),
          ]),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ]);
  }

  static Widget _patternHeader(
      String? pattern, String label, IconData icon, FarwatchColors c) {
    return Row(children: [
      Icon(icon, size: 14, color: c.toolCallAccent),
      const SizedBox(width: 6),
      if (pattern != null)
        Expanded(
          child: Text(
            pattern,
            style: TextStyle(
                color: c.textPrimary,
                fontSize: 12,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ]);
  }

  static Widget _urlHeader(String? url, FarwatchColors c) {
    if (url == null) return const SizedBox.shrink();
    return Row(children: [
      Icon(Icons.language, size: 14, color: c.toolCallAccent),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          url,
          style: TextStyle(
              color: c.accent,
              fontSize: 12,
              decoration: TextDecoration.underline),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Shared wrapper — provides the tool card chrome (icon, name, border).
// ---------------------------------------------------------------------------

class _SmartToolWrapper extends StatelessWidget {
  final String toolName;
  final IconData icon;
  final FarwatchColors colors;
  final Widget child;

  const _SmartToolWrapper({
    required this.toolName,
    required this.icon,
    required this.colors,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.toolCallSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.toolCallBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: colors.toolCallAccent, size: 16),
            const SizedBox(width: 6),
            Text(
              _displayName(toolName),
              style: TextStyle(
                color: colors.toolCallAccent,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ]),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  static String _displayName(String name) {
    return switch (name) {
      'mcp_bash' => 'Terminal',
      'mcp_read' => 'Read File',
      'mcp_edit' => 'Edit File',
      'mcp_write' => 'Write File',
      'mcp_glob' => 'Find Files',
      'mcp_grep' => 'Search Content',
      'mcp_webfetch' => 'Web Fetch',
      'mcp_task' => 'Task',
      'mcp_todowrite' => 'Todo Update',
      _ => name,
    };
  }
}

// ---------------------------------------------------------------------------
// Expandable result section — shared across all smart tool cards.
// ---------------------------------------------------------------------------

class _ExpandableResult extends StatefulWidget {
  final String? result;
  final bool isError;
  final FarwatchColors colors;
  final int collapsedMaxLines;
  final int collapsedMaxChars;

  const _ExpandableResult({
    required this.result,
    required this.isError,
    required this.colors,
    this.collapsedMaxLines = 8,
    this.collapsedMaxChars = 500,
  });

  @override
  State<_ExpandableResult> createState() => _ExpandableResultState();
}

class _ExpandableResultState extends State<_ExpandableResult> {
  bool _expanded = false;

  bool get _isLong =>
      (widget.result?.length ?? 0) > widget.collapsedMaxChars;

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    if (result == null || result.isEmpty) return const SizedBox.shrink();

    final displayText = _expanded || !_isLong
        ? result
        : '${result.substring(0, widget.collapsedMaxChars)}...';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: widget.isError
                ? widget.colors.errorSurface
                : widget.colors.resultSurface,
            borderRadius: BorderRadius.circular(4),
            border: widget.isError
                ? Border.all(color: widget.colors.errorBorder)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.isError)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(Icons.error_outline,
                          size: 13, color: widget.colors.statusErrorAccent),
                    ),
                  Expanded(
                    child: Text(
                      displayText,
                      style: TextStyle(
                        color: widget.isError
                            ? widget.colors.statusErrorAccent
                            : widget.colors.textTertiary,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                      maxLines: _expanded ? 10000 : widget.collapsedMaxLines,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  _SmallCopyButton(text: result, colors: widget.colors),
                ],
              ),
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
      ],
    );
  }
}

class _SmallCopyButton extends StatefulWidget {
  final String text;
  final FarwatchColors colors;
  const _SmallCopyButton({required this.text, required this.colors});

  @override
  State<_SmallCopyButton> createState() => _SmallCopyButtonState();
}

class _SmallCopyButtonState extends State<_SmallCopyButton> {
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
        size: 13,
        color: _copied
            ? widget.colors.statusConnected
            : widget.colors.copyButton,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// mcp_bash — terminal-styled card
// ---------------------------------------------------------------------------

class _BashCard extends StatelessWidget {
  final AgentMessage message;
  final ToolInputParser input;
  final FarwatchColors colors;

  const _BashCard({
    required this.message,
    required this.input,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return _SmartToolWrapper(
      toolName: 'mcp_bash',
      icon: Icons.terminal,
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SmartToolCard._bashHeader(input, colors),
          _ExpandableResult(
            result: message.toolResult,
            isError: message.toolIsError,
            colors: colors,
            collapsedMaxLines: 12,
            collapsedMaxChars: 800,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// mcp_read — file preview card
// ---------------------------------------------------------------------------

class _ReadCard extends StatelessWidget {
  final AgentMessage message;
  final ToolInputParser input;
  final FarwatchColors colors;

  const _ReadCard({
    required this.message,
    required this.input,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return _SmartToolWrapper(
      toolName: 'mcp_read',
      icon: Icons.description_outlined,
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SmartToolCard._filePathHeader(input.filePath, 'Read', colors),
          if (input.offset != null || input.limit != null) ...[
            const SizedBox(height: 2),
            Text(
              [
                if (input.offset != null) 'offset: ${input.offset}',
                if (input.limit != null) 'limit: ${input.limit}',
              ].join(', '),
              style: TextStyle(
                  color: colors.textPlaceholder,
                  fontSize: 10,
                  fontFamily: 'monospace'),
            ),
          ],
          _ExpandableResult(
            result: message.toolResult,
            isError: message.toolIsError,
            colors: colors,
            collapsedMaxLines: 10,
            collapsedMaxChars: 600,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// mcp_edit — diff-style card
// ---------------------------------------------------------------------------

class _EditCard extends StatelessWidget {
  final AgentMessage message;
  final ToolInputParser input;
  final FarwatchColors colors;

  const _EditCard({
    required this.message,
    required this.input,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return _SmartToolWrapper(
      toolName: 'mcp_edit',
      icon: Icons.edit_note,
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SmartToolCard._filePathHeader(input.filePath, 'Edit', colors),
          if (input.replaceAll == true) ...[
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colors.infoSurface,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('Replace All',
                  style: TextStyle(color: colors.infoAccent, fontSize: 10)),
            ),
          ],
          // Show old → new as a mini diff.
          if (input.oldString != null) ...[
            const SizedBox(height: 6),
            _DiffBlock(
              oldText: input.oldString!,
              newText: input.newString,
              colors: colors,
            ),
          ],
          _ExpandableResult(
            result: message.toolResult,
            isError: message.toolIsError,
            colors: colors,
            collapsedMaxLines: 4,
            collapsedMaxChars: 200,
          ),
        ],
      ),
    );
  }
}

/// Simple inline diff showing removed (red) and added (green) lines.
class _DiffBlock extends StatelessWidget {
  final String oldText;
  final String? newText;
  final FarwatchColors colors;

  const _DiffBlock({
    required this.oldText,
    this.newText,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final oldLines = oldText.split('\n');
    final newLines = newText?.split('\n') ?? [];

    // Truncate for display.
    const maxLines = 6;
    final showOld = oldLines.length > maxLines
        ? [...oldLines.take(maxLines), '... +${oldLines.length - maxLines} more']
        : oldLines;
    final showNew = newLines.length > maxLines
        ? [...newLines.take(maxLines), '... +${newLines.length - maxLines} more']
        : newLines;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: colors.codeBlockBackground,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: colors.codeBlockBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in showOld)
            Text(
              '- $line',
              style: TextStyle(
                color: colors.denyText,
                fontFamily: 'monospace',
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          if (showNew.isNotEmpty) ...[
            SizedBox(
                height: 2,
                child: Divider(color: colors.surfaceTertiary, height: 1)),
            for (final line in showNew)
              Text(
                '+ $line',
                style: TextStyle(
                  color: colors.approveText,
                  fontFamily: 'monospace',
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// mcp_write — new file card
// ---------------------------------------------------------------------------

class _WriteCard extends StatelessWidget {
  final AgentMessage message;
  final ToolInputParser input;
  final FarwatchColors colors;

  const _WriteCard({
    required this.message,
    required this.input,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return _SmartToolWrapper(
      toolName: 'mcp_write',
      icon: Icons.note_add_outlined,
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.insert_drive_file_outlined,
                size: 14, color: colors.toolCallAccent),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                input.filePath ?? 'unknown',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colors.statusConnected.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('New',
                  style: TextStyle(
                      color: colors.statusConnected, fontSize: 10)),
            ),
          ]),
          if (input.content != null) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: colors.codeBlockBackground,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: colors.codeBlockBorder),
              ),
              child: SingleChildScrollView(
                child: Text(
                  input.content!.length > 500
                      ? '${input.content!.substring(0, 500)}...'
                      : input.content!,
                  style: TextStyle(
                    color: colors.textTertiary,
                    fontFamily: 'monospace',
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ],
          _ExpandableResult(
            result: message.toolResult,
            isError: message.toolIsError,
            colors: colors,
            collapsedMaxLines: 3,
            collapsedMaxChars: 200,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// mcp_glob — file list card
// ---------------------------------------------------------------------------

class _GlobCard extends StatelessWidget {
  final AgentMessage message;
  final ToolInputParser input;
  final FarwatchColors colors;

  const _GlobCard({
    required this.message,
    required this.input,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return _SmartToolWrapper(
      toolName: 'mcp_glob',
      icon: Icons.folder_open,
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SmartToolCard._patternHeader(
              input.pattern, 'Glob', Icons.folder_open, colors),
          if (input.path != null) ...[
            const SizedBox(height: 2),
            Text(
              'in ${input.path}',
              style: TextStyle(
                  color: colors.textPlaceholder,
                  fontSize: 10,
                  fontFamily: 'monospace'),
            ),
          ],
          _fileListResult(message.toolResult, colors),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// mcp_grep — search results card
// ---------------------------------------------------------------------------

class _GrepCard extends StatelessWidget {
  final AgentMessage message;
  final ToolInputParser input;
  final FarwatchColors colors;

  const _GrepCard({
    required this.message,
    required this.input,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return _SmartToolWrapper(
      toolName: 'mcp_grep',
      icon: Icons.search,
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SmartToolCard._patternHeader(
              input.pattern, 'Grep', Icons.search, colors),
          if (input.include != null) ...[
            const SizedBox(height: 2),
            Text(
              'include: ${input.include}',
              style: TextStyle(
                  color: colors.textPlaceholder,
                  fontSize: 10,
                  fontFamily: 'monospace'),
            ),
          ],
          _fileListResult(message.toolResult, colors),
        ],
      ),
    );
  }
}

/// Renders a tool result that contains a list of file paths as
/// clickable-looking file entries with icons.
Widget _fileListResult(String? result, FarwatchColors colors) {
  if (result == null || result.isEmpty) return const SizedBox.shrink();

  final lines = result.split('\n').where((l) => l.trim().isNotEmpty).toList();
  final displayLines = lines.length > 15 ? lines.take(15).toList() : lines;
  final remaining = lines.length - displayLines.length;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 6),
      for (final line in displayLines)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Row(children: [
            Icon(
              line.endsWith('/') ? Icons.folder : Icons.insert_drive_file_outlined,
              size: 12,
              color: colors.textPlaceholder,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                line,
                style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 11,
                    fontFamily: 'monospace'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
        ),
      if (remaining > 0) ...[
        const SizedBox(height: 4),
        Text(
          '... +$remaining more files',
          style: TextStyle(color: colors.textPlaceholder, fontSize: 10),
        ),
      ],
    ],
  );
}

// ---------------------------------------------------------------------------
// mcp_webfetch — URL preview card
// ---------------------------------------------------------------------------

class _WebFetchCard extends StatelessWidget {
  final AgentMessage message;
  final ToolInputParser input;
  final FarwatchColors colors;

  const _WebFetchCard({
    required this.message,
    required this.input,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return _SmartToolWrapper(
      toolName: 'mcp_webfetch',
      icon: Icons.language,
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SmartToolCard._urlHeader(input.url, colors),
          if (input.format != null) ...[
            const SizedBox(height: 2),
            Text(
              'format: ${input.format}',
              style: TextStyle(
                  color: colors.textPlaceholder,
                  fontSize: 10,
                  fontFamily: 'monospace'),
            ),
          ],
          _ExpandableResult(
            result: message.toolResult,
            isError: message.toolIsError,
            colors: colors,
            collapsedMaxLines: 8,
            collapsedMaxChars: 400,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Generic fallback — for unrecognized tool names
// ---------------------------------------------------------------------------

class _GenericToolCard extends StatelessWidget {
  final AgentMessage message;
  final ToolInputParser input;
  final FarwatchColors colors;

  const _GenericToolCard({
    required this.message,
    required this.input,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return _SmartToolWrapper(
      toolName: message.toolName ?? message.text,
      icon: Icons.build,
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.toolInput != null && message.toolInput!.isNotEmpty)
            Text(
              message.toolInput!.length > 200
                  ? '${message.toolInput!.substring(0, 200)}...'
                  : message.toolInput!,
              style: TextStyle(
                  color: colors.textTertiary,
                  fontSize: 11,
                  fontFamily: 'monospace'),
            ),
          _ExpandableResult(
            result: message.toolResult,
            isError: message.toolIsError,
            colors: colors,
          ),
        ],
      ),
    );
  }
}
