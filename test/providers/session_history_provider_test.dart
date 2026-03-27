import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:farwatch_app/core/session_history.dart';
import 'package:farwatch_app/providers/session_history_provider.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer();
  });

  tearDown(() => container.dispose());

  SessionRecord makeRecord(String id, {String? toolName}) {
    return SessionRecord(
      pairingUri: 'farwatch://pair?relay=wss://r&session=$id&code=aaa-bbb-ccc',
      sessionId: id,
      relayUrl: 'wss://r',
      toolName: toolName,
      connectedAt: DateTime(2025, 1, 1),
      lastActiveAt: DateTime(2025, 1, 1),
    );
  }

  group('SessionHistoryNotifier', () {
    test('initial load returns empty list', () async {
      // Wait for async build to complete.
      await container.read(sessionHistoryProvider.future);
      final state = container.read(sessionHistoryProvider);
      expect(state.valueOrNull, isEmpty);
    });

    test('upsert adds a record', () async {
      await container.read(sessionHistoryProvider.future);
      final notifier = container.read(sessionHistoryProvider.notifier);

      await notifier.upsert(makeRecord('s1', toolName: 'claude'));
      final records = container.read(sessionHistoryProvider).valueOrNull!;
      expect(records, hasLength(1));
      expect(records.first.sessionId, 's1');
      expect(records.first.toolName, 'claude');
    });

    test('upsert moves existing record to top', () async {
      await container.read(sessionHistoryProvider.future);
      final notifier = container.read(sessionHistoryProvider.notifier);

      await notifier.upsert(makeRecord('s1'));
      await notifier.upsert(makeRecord('s2'));
      await notifier.upsert(makeRecord('s1', toolName: 'updated'));

      final records = container.read(sessionHistoryProvider).valueOrNull!;
      expect(records, hasLength(2));
      expect(records.first.sessionId, 's1');
      expect(records.first.toolName, 'updated');
    });

    test('updateSession modifies existing record', () async {
      await container.read(sessionHistoryProvider.future);
      final notifier = container.read(sessionHistoryProvider.notifier);

      await notifier.upsert(makeRecord('s1'));
      await notifier.updateSession('s1',
          endReason: SessionEndReason.hostEnded);

      final records = container.read(sessionHistoryProvider).valueOrNull!;
      expect(records.first.endReason, SessionEndReason.hostEnded);
    });

    test('updateSession is no-op for unknown session', () async {
      await container.read(sessionHistoryProvider.future);
      final notifier = container.read(sessionHistoryProvider.notifier);

      await notifier.upsert(makeRecord('s1'));
      await notifier.updateSession('nonexistent',
          endReason: SessionEndReason.connectionLost);

      final records = container.read(sessionHistoryProvider).valueOrNull!;
      expect(records, hasLength(1));
      expect(records.first.endReason, SessionEndReason.unknown);
    });

    test('remove deletes a record', () async {
      await container.read(sessionHistoryProvider.future);
      final notifier = container.read(sessionHistoryProvider.notifier);

      await notifier.upsert(makeRecord('s1'));
      await notifier.upsert(makeRecord('s2'));
      await notifier.remove('s1');

      final records = container.read(sessionHistoryProvider).valueOrNull!;
      expect(records, hasLength(1));
      expect(records.first.sessionId, 's2');
    });

    test('clear removes all records', () async {
      await container.read(sessionHistoryProvider.future);
      final notifier = container.read(sessionHistoryProvider.notifier);

      await notifier.upsert(makeRecord('s1'));
      await notifier.upsert(makeRecord('s2'));
      await notifier.clear();

      final records = container.read(sessionHistoryProvider).valueOrNull!;
      expect(records, isEmpty);
    });

    test('data persists across provider rebuilds', () async {
      await container.read(sessionHistoryProvider.future);
      final notifier = container.read(sessionHistoryProvider.notifier);
      await notifier.upsert(makeRecord('s1', toolName: 'persisted'));

      // Create new container (simulates app restart, same SharedPreferences).
      container.dispose();
      container = ProviderContainer();
      await container.read(sessionHistoryProvider.future);

      final records = container.read(sessionHistoryProvider).valueOrNull!;
      expect(records, hasLength(1));
      expect(records.first.toolName, 'persisted');
    });
  });
}
