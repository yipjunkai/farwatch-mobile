import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/protocol.dart';
import '../models/agent_message.dart';

/// Immutable snapshot of the structured agent view state.
@immutable
class AgentState {
  final List<AgentMessage> messages;
  final bool agentBusy;

  /// True while a turn has started but no text/tool content has arrived yet.
  /// Used to show a typing indicator in the chat UI.
  final bool agentTyping;
  final bool hasStructuredEvents;
  final bool showStructuredView;
  final Map<String, String?> pendingPermissions;

  /// Pending question IDs → whether answered (null = pending, non-null = answered).
  final Map<String, List<String>?> pendingQuestions;
  final List<TodoItem> todos;
  final double costUsd;
  final int inputTokens;
  final int outputTokens;

  const AgentState({
    this.messages = const [],
    this.agentBusy = false,
    this.agentTyping = false,
    this.hasStructuredEvents = false,
    this.showStructuredView = false,
    this.pendingPermissions = const {},
    this.pendingQuestions = const {},
    this.todos = const [],
    this.costUsd = 0.0,
    this.inputTokens = 0,
    this.outputTokens = 0,
  });

  AgentState copyWith({
    List<AgentMessage>? messages,
    bool? agentBusy,
    bool? agentTyping,
    bool? hasStructuredEvents,
    bool? showStructuredView,
    Map<String, String?>? pendingPermissions,
    Map<String, List<String>?>? pendingQuestions,
    List<TodoItem>? todos,
    double? costUsd,
    int? inputTokens,
    int? outputTokens,
  }) {
    return AgentState(
      messages: messages ?? this.messages,
      agentBusy: agentBusy ?? this.agentBusy,
      agentTyping: agentTyping ?? this.agentTyping,
      hasStructuredEvents: hasStructuredEvents ?? this.hasStructuredEvents,
      showStructuredView: showStructuredView ?? this.showStructuredView,
      pendingPermissions: pendingPermissions ?? this.pendingPermissions,
      pendingQuestions: pendingQuestions ?? this.pendingQuestions,
      todos: todos ?? this.todos,
      costUsd: costUsd ?? this.costUsd,
      inputTokens: inputTokens ?? this.inputTokens,
      outputTokens: outputTokens ?? this.outputTokens,
    );
  }
}

/// Provider for agent state. AutoDispose ensures cleanup when
/// the terminal screen is popped.
final agentStateProvider =
    NotifierProvider.autoDispose<AgentStateNotifier, AgentState>(
  AgentStateNotifier.new,
);

class AgentStateNotifier extends AutoDisposeNotifier<AgentState> {
  int _nextId = 0;

  @override
  AgentState build() => const AgentState();

  /// Toggle between structured and terminal views.
  void toggleView() {
    state = state.copyWith(showStructuredView: !state.showStructuredView);
  }

  /// Set the structured view visible and mark that events have arrived.
  void enableStructuredView() {
    state = state.copyWith(
      hasStructuredEvents: true,
      showStructuredView: true,
    );
  }

  /// Add a user prompt message to the chat history (called before sending).
  void addUserPrompt(String text) {
    final messages = List<AgentMessage>.of(state.messages);
    messages.add(AgentMessage(
      id: _nextId++,
      type: AgentMessageType.userPrompt,
      text: text,
    ));
    state = state.copyWith(messages: messages);
  }

  /// Process an inbound [SecureMessage] from the relay session.
  ///
  /// Returns a [String?] toast message if the event should show a notification.
  String? handleEvent(SecureMessage msg) {
    switch (msg) {
      case SessionEnded(exitCode: final code):
        return 'Session ended (exit code: $code)';

      case VersionNotice(minimumVersion: final v):
        return 'Minimum version required: $v';

      case AgentSessionInit(model: final model, tools: final tools):
        final messages = List<AgentMessage>.of(state.messages);
        messages.add(AgentMessage(
          id: _nextId++,
          type: AgentMessageType.system,
          text: 'Model: $model\nTools: ${tools.join(", ")}',
        ));
        state = state.copyWith(
          messages: messages,
          hasStructuredEvents: true,
          showStructuredView: true,
        );
        return null;

      case AgentTurnStarted():
        final messages = List<AgentMessage>.of(state.messages);
        messages.add(AgentMessage(
          id: _nextId++,
          type: AgentMessageType.turnMarker,
          text: 'Turn started...',
        ));
        state = state.copyWith(
          messages: messages,
          agentBusy: true,
          agentTyping: true,
        );
        return null;

      case AgentTextDelta(text: final text):
        final messages = List<AgentMessage>.of(state.messages);
        if (messages.isNotEmpty &&
            messages.last.type == AgentMessageType.text) {
          messages.last.text += text;
        } else {
          messages.add(AgentMessage(
            id: _nextId++,
            type: AgentMessageType.text,
            text: text,
          ));
        }
        state = state.copyWith(messages: messages, agentTyping: false);
        return null;

      case AgentThinkingDelta(text: final text):
        final messages = List<AgentMessage>.of(state.messages);
        if (messages.isNotEmpty &&
            messages.last.type == AgentMessageType.thinking) {
          messages.last.text += text;
        } else {
          messages.add(AgentMessage(
            id: _nextId++,
            type: AgentMessageType.thinking,
            text: text,
          ));
        }
        state = state.copyWith(messages: messages, agentTyping: false);
        return null;

      case AgentToolUseStart(id: final id, name: final name, input: final input):
        // Intercept mcp_question tool calls → render as native question UI.
        if (name == 'mcp_question') {
          return _handleQuestionTool(id, input);
        }
        final messages = List<AgentMessage>.of(state.messages);
        messages.add(AgentMessage(
          id: _nextId++,
          type: AgentMessageType.toolCall,
          text: name,
          toolId: id,
          toolInput: input,
        ));
        state = state.copyWith(messages: messages, agentTyping: false);
        return null;

      case AgentToolResult(
          id: final id,
          content: final result,
          isError: final isError):
        final messages = List<AgentMessage>.of(state.messages);
        messages.add(AgentMessage(
          id: _nextId++,
          type: isError ? AgentMessageType.toolError : AgentMessageType.toolResult,
          text: result,
          toolId: id,
        ));
        state = state.copyWith(messages: messages);
        return null;

      case AgentTurnCompleted():
        state = state.copyWith(agentBusy: false, agentTyping: false);
        return null;

      case AgentSessionResult(result: final result, isError: final isError):
        final messages = List<AgentMessage>.of(state.messages);
        messages.add(AgentMessage(
          id: _nextId++,
          type: isError ? AgentMessageType.toolError : AgentMessageType.text,
          text: result,
        ));
        state = state.copyWith(messages: messages, agentBusy: false, agentTyping: false);
        return null;

      case AgentPermissionRequest(
          id: final id,
          tool: final name,
          title: final desc,
          metadata: final input):
        final messages = List<AgentMessage>.of(state.messages);
        messages.add(AgentMessage(
          id: _nextId++,
          type: AgentMessageType.permissionRequest,
          text: desc,
          toolId: id,
          toolInput: input,
          toolName: name,
        ));
        final perms = Map<String, String?>.of(state.pendingPermissions);
        perms[id] = null;
        state = state.copyWith(
          messages: messages,
          pendingPermissions: perms,
          agentTyping: false,
        );
        return null;

      case AgentPermissionResolved(id: final id, response: final response):
        final perms = Map<String, String?>.of(state.pendingPermissions);
        perms[id] = response;
        state = state.copyWith(pendingPermissions: perms);
        return null;

      case AgentCostUpdate(
          costUsd: final cost,
          inputTokens: final input,
          outputTokens: final output):
        state = state.copyWith(
          costUsd: cost,
          inputTokens: input,
          outputTokens: output,
        );
        return null;

      case AgentTodoUpdate(todos: final items):
        state = state.copyWith(todos: items);
        return null;

      // Remaining SecureMessage subtypes not handled here.
      default:
        return null;
    }
  }

  /// Intercept an `mcp_question` tool call and render as a question card.
  String? _handleQuestionTool(String toolId, String inputJson) {
    QuestionData? questionData;
    try {
      final parsed = jsonDecode(inputJson) as Map<String, dynamic>;
      questionData = QuestionData.fromJson(parsed);
    } catch (_) {
      // Malformed question input — fall back to generic tool card.
      final messages = List<AgentMessage>.of(state.messages);
      messages.add(AgentMessage(
        id: _nextId++,
        type: AgentMessageType.toolCall,
        text: 'mcp_question',
        toolId: toolId,
        toolInput: inputJson,
      ));
      state = state.copyWith(messages: messages, agentTyping: false);
      return null;
    }

    final messages = List<AgentMessage>.of(state.messages);
    messages.add(AgentMessage(
      id: _nextId++,
      type: AgentMessageType.questionRequest,
      text: questionData.questions.isNotEmpty
          ? questionData.questions.first.question
          : 'Question',
      toolId: toolId,
      questionData: questionData,
    ));

    final questions = Map<String, List<String>?>.of(state.pendingQuestions);
    questions[toolId] = null; // null = unanswered

    state = state.copyWith(
      messages: messages,
      pendingQuestions: questions,
      agentTyping: false,
    );
    return null;
  }

  /// Resolve a permission (called from permission card buttons).
  void resolvePermission(String id, String response) {
    final perms = Map<String, String?>.of(state.pendingPermissions);
    perms[id] = response;
    state = state.copyWith(pendingPermissions: perms);
  }

  /// Mark a question as answered with the selected labels.
  void resolveQuestion(String toolId, List<String> selectedLabels) {
    final questions = Map<String, List<String>?>.of(state.pendingQuestions);
    questions[toolId] = selectedLabels;
    state = state.copyWith(pendingQuestions: questions);
  }
}
