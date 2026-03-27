import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/protocol.dart';
import '../models/agent_message.dart';

/// Immutable snapshot of the structured agent view state.
@immutable
class AgentState {
  final List<AgentMessage> messages;
  final bool agentBusy;
  final bool hasStructuredEvents;
  final bool showStructuredView;
  final Map<String, String?> pendingPermissions;
  final List<TodoItem> todos;
  final double costUsd;
  final int inputTokens;
  final int outputTokens;

  const AgentState({
    this.messages = const [],
    this.agentBusy = false,
    this.hasStructuredEvents = false,
    this.showStructuredView = false,
    this.pendingPermissions = const {},
    this.todos = const [],
    this.costUsd = 0.0,
    this.inputTokens = 0,
    this.outputTokens = 0,
  });

  AgentState copyWith({
    List<AgentMessage>? messages,
    bool? agentBusy,
    bool? hasStructuredEvents,
    bool? showStructuredView,
    Map<String, String?>? pendingPermissions,
    List<TodoItem>? todos,
    double? costUsd,
    int? inputTokens,
    int? outputTokens,
  }) {
    return AgentState(
      messages: messages ?? this.messages,
      agentBusy: agentBusy ?? this.agentBusy,
      hasStructuredEvents: hasStructuredEvents ?? this.hasStructuredEvents,
      showStructuredView: showStructuredView ?? this.showStructuredView,
      pendingPermissions: pendingPermissions ?? this.pendingPermissions,
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

  /// Process an inbound [SecureMessage] from the relay session.
  ///
  /// This is the 130-line switch statement extracted from terminal_screen.dart.
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
        state = state.copyWith(messages: messages, agentBusy: true);
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
        state = state.copyWith(messages: messages);
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
        state = state.copyWith(messages: messages);
        return null;

      case AgentToolUseStart(id: final id, name: final name, input: final input):
        final messages = List<AgentMessage>.of(state.messages);
        messages.add(AgentMessage(
          id: _nextId++,
          type: AgentMessageType.toolCall,
          text: name,
          toolId: id,
          toolInput: input,
        ));
        state = state.copyWith(messages: messages);
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
        state = state.copyWith(agentBusy: false);
        return null;

      case AgentSessionResult(result: final result, isError: final isError):
        final messages = List<AgentMessage>.of(state.messages);
        messages.add(AgentMessage(
          id: _nextId++,
          type: isError ? AgentMessageType.toolError : AgentMessageType.text,
          text: result,
        ));
        state = state.copyWith(messages: messages, agentBusy: false);
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
        state = state.copyWith(messages: messages, pendingPermissions: perms);
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

  /// Resolve a permission (called from permission card buttons).
  void resolvePermission(String id, String response) {
    final perms = Map<String, String?>.of(state.pendingPermissions);
    perms[id] = response;
    state = state.copyWith(pendingPermissions: perms);
  }
}
