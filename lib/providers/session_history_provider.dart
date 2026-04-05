import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/session_history.dart';
import '../data/session_history_repository.dart';

/// App-level provider for the [SessionHistoryRepository] singleton.
final sessionHistoryRepositoryProvider = Provider<SessionHistoryRepository>(
  (ref) => SessionHistoryRepository(),
);

/// Async provider that exposes the session history list.
///
/// Widgets use `ref.watch(sessionHistoryProvider)` which returns an
/// `AsyncValue<List<SessionRecord>>` — handled with `.when(data:, loading:, error:)`.
///
/// Mutations (`upsert`, `update`, `remove`, `clear`) are done via the notifier:
/// `ref.read(sessionHistoryProvider.notifier).upsert(record)`.
final sessionHistoryProvider =
    AsyncNotifierProvider<SessionHistoryNotifier, List<SessionRecord>>(
      SessionHistoryNotifier.new,
    );

class SessionHistoryNotifier extends AsyncNotifier<List<SessionRecord>> {
  SessionHistoryRepository get _repo =>
      ref.read(sessionHistoryRepositoryProvider);

  @override
  Future<List<SessionRecord>> build() async {
    return _repo.load();
  }

  /// Add or update a session record.
  Future<void> upsert(SessionRecord record) async {
    await _repo.upsert(record);
    state = AsyncData(await _repo.load());
  }

  /// Update fields on an existing session.
  Future<void> updateSession(
    String sessionId, {
    String? toolName,
    DateTime? lastActiveAt,
    SessionEndReason? endReason,
  }) async {
    await _repo.update(
      sessionId,
      toolName: toolName,
      lastActiveAt: lastActiveAt,
      endReason: endReason,
    );
    state = AsyncData(await _repo.load());
  }

  /// Remove a single session.
  Future<void> remove(String sessionId) async {
    await _repo.remove(sessionId);
    state = AsyncData(await _repo.load());
  }

  /// Clear all history.
  Future<void> clear() async {
    await _repo.clear();
    state = const AsyncData([]);
  }
}
