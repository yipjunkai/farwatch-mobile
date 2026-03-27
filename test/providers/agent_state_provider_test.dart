import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:farwatch_app/core/protocol.dart';
import 'package:farwatch_app/models/agent_message.dart';
import 'package:farwatch_app/providers/agent_state_provider.dart';

void main() {
  late ProviderContainer container;
  late AgentStateNotifier notifier;

  setUp(() {
    container = ProviderContainer();
    notifier = container.read(agentStateProvider.notifier);
  });

  tearDown(() => container.dispose());

  group('AgentStateNotifier', () {
    test('initial state is empty', () {
      final state = container.read(agentStateProvider);
      expect(state.messages, isEmpty);
      expect(state.agentBusy, false);
      expect(state.hasStructuredEvents, false);
      expect(state.showStructuredView, false);
      expect(state.pendingPermissions, isEmpty);
      expect(state.todos, isEmpty);
      expect(state.costUsd, 0.0);
    });

    test('toggleView flips showStructuredView', () {
      notifier.toggleView();
      expect(container.read(agentStateProvider).showStructuredView, true);
      notifier.toggleView();
      expect(container.read(agentStateProvider).showStructuredView, false);
    });

    test('enableStructuredView sets both flags', () {
      notifier.enableStructuredView();
      final state = container.read(agentStateProvider);
      expect(state.hasStructuredEvents, true);
      expect(state.showStructuredView, true);
    });

    test('handleEvent SessionEnded returns toast', () {
      final toast = notifier.handleEvent(SessionEnded(0));
      expect(toast, contains('Session ended'));
    });

    test('handleEvent VersionNotice returns toast', () {
      final toast = notifier.handleEvent(VersionNotice('2.0'));
      expect(toast, contains('2.0'));
    });

    test('handleEvent AgentSessionInit adds system message', () {
      notifier.handleEvent(AgentSessionInit(sessionId: 'sess1', model: 'claude', tools: ['bash', 'write']));
      final state = container.read(agentStateProvider);
      expect(state.messages, hasLength(1));
      expect(state.messages.first.type, AgentMessageType.system);
      expect(state.messages.first.text, contains('claude'));
      expect(state.hasStructuredEvents, true);
      expect(state.showStructuredView, true);
    });

    test('handleEvent AgentTurnStarted sets agentBusy', () {
      notifier.handleEvent(AgentTurnStarted());
      final state = container.read(agentStateProvider);
      expect(state.agentBusy, true);
      expect(state.messages.last.type, AgentMessageType.turnMarker);
    });

    test('handleEvent AgentTextDelta appends to last text message', () {
      notifier.handleEvent(AgentTextDelta(text: 'Hello '));
      notifier.handleEvent(AgentTextDelta(text: 'World'));
      final state = container.read(agentStateProvider);
      expect(state.messages, hasLength(1));
      expect(state.messages.first.text, 'Hello World');
    });

    test('handleEvent AgentTextDelta creates new message after non-text', () {
      notifier.handleEvent(AgentTurnStarted());
      notifier.handleEvent(AgentTextDelta(text: 'First'));
      final state = container.read(agentStateProvider);
      expect(state.messages, hasLength(2)); // turnMarker + text
    });

    test('handleEvent AgentThinkingDelta appends to last thinking', () {
      notifier.handleEvent(AgentThinkingDelta(text: 'Thinking '));
      notifier.handleEvent(AgentThinkingDelta(text: 'deeply'));
      final state = container.read(agentStateProvider);
      expect(state.messages, hasLength(1));
      expect(state.messages.first.type, AgentMessageType.thinking);
      expect(state.messages.first.text, 'Thinking deeply');
    });

    test('handleEvent AgentToolUseStart adds tool call message', () {
      notifier.handleEvent(AgentToolUseStart(id: 't1', name: 'bash', input: 'ls -la'));
      final state = container.read(agentStateProvider);
      expect(state.messages.last.type, AgentMessageType.toolCall);
      expect(state.messages.last.text, 'bash');
      expect(state.messages.last.toolId, 't1');
      expect(state.messages.last.toolInput, 'ls -la');
    });

    test('handleEvent AgentToolResult adds result message', () {
      notifier.handleEvent(AgentToolResult(id: 't1', content: 'output', isError: false));
      final state = container.read(agentStateProvider);
      expect(state.messages.last.type, AgentMessageType.toolResult);
    });

    test('handleEvent AgentToolResult with error adds error message', () {
      notifier.handleEvent(AgentToolResult(id: 't1', content: 'failed', isError: true));
      final state = container.read(agentStateProvider);
      expect(state.messages.last.type, AgentMessageType.toolError);
    });

    test('handleEvent AgentTurnCompleted clears agentBusy', () {
      notifier.handleEvent(AgentTurnStarted());
      expect(container.read(agentStateProvider).agentBusy, true);
      notifier.handleEvent(AgentTurnCompleted(status: 'completed'));
      expect(container.read(agentStateProvider).agentBusy, false);
    });

    test('handleEvent AgentPermissionRequest tracks pending permission', () {
      notifier.handleEvent(AgentPermissionRequest(
        id: 'p1',
        tool: 'bash',
        title: 'Run command?',
        metadata: 'rm -rf /',
      ));
      final state = container.read(agentStateProvider);
      expect(state.messages.last.type, AgentMessageType.permissionRequest);
      expect(state.pendingPermissions['p1'], isNull); // pending
    });

    test('handleEvent AgentPermissionResolved updates permission', () {
      notifier.handleEvent(AgentPermissionRequest(
        id: 'p1', tool: 'bash', title: 'Run?', metadata: '',
      ));
      notifier.handleEvent(AgentPermissionResolved(id: 'p1', response: 'allow'));
      final state = container.read(agentStateProvider);
      expect(state.pendingPermissions['p1'], 'allow');
    });

    test('resolvePermission updates pending permission', () {
      notifier.handleEvent(AgentPermissionRequest(
        id: 'p2', tool: 'write', title: 'Write?', metadata: '',
      ));
      notifier.resolvePermission('p2', 'deny');
      expect(container.read(agentStateProvider).pendingPermissions['p2'], 'deny');
    });

    test('handleEvent AgentCostUpdate updates cost and tokens', () {
      notifier.handleEvent(AgentCostUpdate(
        costUsd: 0.0042,
        inputTokens: 1500,
        outputTokens: 500,
        reasoningTokens: 0,
        cacheReadTokens: 0,
        cacheWriteTokens: 0,
      ));
      final state = container.read(agentStateProvider);
      expect(state.costUsd, 0.0042);
      expect(state.inputTokens, 1500);
      expect(state.outputTokens, 500);
    });

    test('handleEvent AgentTodoUpdate replaces todos', () {
      notifier.handleEvent(AgentTodoUpdate(todos: [
        TodoItem(id: '1', content: 'Task 1', status: 'pending', priority: 'high'),
        TodoItem(id: '2', content: 'Task 2', status: 'completed', priority: 'low'),
      ]));
      final state = container.read(agentStateProvider);
      expect(state.todos, hasLength(2));
      expect(state.todos.first.content, 'Task 1');
    });

    test('handleEvent PtyOutput returns null (ignored)', () {
      final toast = notifier.handleEvent(PtyOutput(Uint8List.fromList([65])));
      expect(toast, isNull);
    });

    test('messages have unique incrementing IDs', () {
      notifier.handleEvent(AgentTextDelta(text: 'a'));
      notifier.handleEvent(AgentTurnStarted());
      notifier.handleEvent(AgentTextDelta(text: 'b'));
      final ids = container
          .read(agentStateProvider)
          .messages
          .map((m) => m.id)
          .toList();
      expect(ids, orderedEquals([0, 1, 2]));
    });
  });
}
