/// Type of agent message for rendering different card styles.
enum AgentMessageType {
  system,
  text,
  thinking,
  toolCall,
  toolResult,
  toolError,
  turnMarker,
  permissionRequest,
  questionRequest,
  userPrompt,
}

// ---------------------------------------------------------------------------
// Question data model (parsed from mcp_question tool input)
// ---------------------------------------------------------------------------

/// A single option within a question.
class QuestionOption {
  final String label;
  final String description;

  const QuestionOption({required this.label, required this.description});

  factory QuestionOption.fromJson(Map<String, dynamic> json) => QuestionOption(
    label: json['label'] as String? ?? '',
    description: json['description'] as String? ?? '',
  );
}

/// A single question with header, options, and whether multiple selections are allowed.
class QuestionItem {
  final String header;
  final String question;
  final List<QuestionOption> options;
  final bool multiple;

  const QuestionItem({
    required this.header,
    required this.question,
    required this.options,
    this.multiple = false,
  });

  factory QuestionItem.fromJson(Map<String, dynamic> json) => QuestionItem(
    header: json['header'] as String? ?? '',
    question: json['question'] as String? ?? '',
    options:
        (json['options'] as List<dynamic>?)
            ?.map((o) => QuestionOption.fromJson(o as Map<String, dynamic>))
            .toList() ??
        [],
    multiple: json['multiple'] as bool? ?? false,
  );

  /// True when this is a simple binary choice (2 options, not multi-select).
  bool get isBinary => options.length == 2 && !multiple;
}

/// Parsed question data from a question tool call.
///
/// Supports two formats:
///  - Full: `{ "questions": [ { "header", "question", "options", ... } ] }`
///  - Simple: `{ "question": "...", "options": [...] }` (Claude Code)
class QuestionData {
  final List<QuestionItem> questions;

  const QuestionData({required this.questions});

  factory QuestionData.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('questions') && json['questions'] is List) {
      return QuestionData(
        questions: (json['questions'] as List<dynamic>)
            .map((q) => QuestionItem.fromJson(q as Map<String, dynamic>))
            .toList(),
      );
    }

    if (json.containsKey('question')) {
      final rawOptions = json['options'] as List<dynamic>? ?? [];
      final options = rawOptions.map((o) {
        if (o is Map<String, dynamic>) return QuestionOption.fromJson(o);
        return QuestionOption(label: o.toString(), description: '');
      }).toList();

      return QuestionData(
        questions: [
          QuestionItem(
            header: json['title'] as String? ?? 'Question',
            question: json['question'] as String? ?? '',
            options: options,
            multiple: json['multiple'] as bool? ?? false,
          ),
        ],
      );
    }

    return const QuestionData(questions: []);
  }
}

// ---------------------------------------------------------------------------
// Agent message
// ---------------------------------------------------------------------------

/// A single message in the structured agent view.
///
/// Mutable `text` field allows streaming deltas to append in place
/// (text and thinking messages grow incrementally).
///
/// For tool calls, `toolResult` / `toolIsError` / `toolRunning` track the
/// lifecycle so the card can show a loading shimmer, then the result inline.
class AgentMessage {
  final int id;
  final AgentMessageType type;
  String text;
  final String? toolId;
  final String? toolInput;
  final String? toolName;

  /// Parsed question data (only for [AgentMessageType.questionRequest]).
  final QuestionData? questionData;

  /// Whether this tool call is still running (no result yet).
  bool toolRunning;

  /// The tool's output content (populated when [AgentToolResult] arrives).
  String? toolResult;

  /// Whether the tool result was an error.
  bool toolIsError;

  /// Timestamp when the tool call started (for elapsed time display).
  final DateTime? toolStartedAt;

  AgentMessage({
    required this.id,
    required this.type,
    required this.text,
    this.toolId,
    this.toolInput,
    this.toolName,
    this.questionData,
    this.toolRunning = false,
    this.toolResult,
    this.toolIsError = false,
    this.toolStartedAt,
  });
}
