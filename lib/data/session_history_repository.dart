import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/session_history.dart';

/// Persistence layer for [SessionRecord]s, backed by [SharedPreferences].
///
/// Unlike the old static [SessionHistory] class, this is an injectable
/// instance that:
/// - Caches the [SharedPreferences] singleton (one `getInstance()` call).
/// - Keeps the loaded list in memory so reads don't re-parse JSON.
/// - Is testable via constructor injection of a mock [SharedPreferences].
class SessionHistoryRepository {
  static const _key = 'session_history';
  static const _maxRecords = 50;

  SharedPreferences? _prefs;
  List<SessionRecord>? _cache;

  /// Get or initialize the [SharedPreferences] instance.
  Future<SharedPreferences> get _preferences async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  /// Load all session records. Returns the cached list on subsequent calls.
  Future<List<SessionRecord>> load() async {
    if (_cache != null) return List.unmodifiable(_cache!);

    final prefs = await _preferences;
    final raw = prefs.getString(_key);
    if (raw == null) {
      _cache = [];
      return List.unmodifiable(_cache!);
    }

    try {
      final list = jsonDecode(raw) as List<dynamic>;
      _cache = list
          .map((e) => SessionRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      _cache = [];
    }
    return List.unmodifiable(_cache!);
  }

  /// Add or update a session record. If a record with the same [SessionRecord.sessionId]
  /// already exists, it is replaced and moved to the top.
  Future<void> upsert(SessionRecord record) async {
    await _ensureLoaded();
    _cache!.removeWhere((r) => r.sessionId == record.sessionId);
    _cache!.insert(0, record);
    await _persist();
  }

  /// Update only the fields that changed for an existing session.
  Future<void> update(
    String sessionId, {
    String? toolName,
    DateTime? lastActiveAt,
    SessionEndReason? endReason,
  }) async {
    await _ensureLoaded();
    final idx = _cache!.indexWhere((r) => r.sessionId == sessionId);
    if (idx == -1) return;

    _cache![idx] = _cache![idx].copyWith(
      toolName: toolName,
      lastActiveAt: lastActiveAt,
      endReason: endReason,
    );
    await _persist();
  }

  /// Remove a single session record.
  Future<void> remove(String sessionId) async {
    await _ensureLoaded();
    _cache!.removeWhere((r) => r.sessionId == sessionId);
    await _persist();
  }

  /// Clear all session history.
  Future<void> clear() async {
    _cache = [];
    final prefs = await _preferences;
    await prefs.remove(_key);
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  Future<void> _ensureLoaded() async {
    if (_cache == null) await load();
  }

  Future<void> _persist() async {
    final prefs = await _preferences;
    final trimmed = _cache!.length > _maxRecords
        ? _cache!.sublist(0, _maxRecords)
        : _cache!;
    _cache = trimmed;
    await prefs.setString(
      _key,
      jsonEncode(trimmed.map((r) => r.toJson()).toList()),
    );
  }
}
