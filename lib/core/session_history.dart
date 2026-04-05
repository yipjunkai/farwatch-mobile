import 'pairing.dart';

/// A record of a previous terminal session, persisted locally.
class SessionRecord {
  /// The full pairing URI (for reconnect attempts).
  final String pairingUri;

  /// The session ID from the pairing URI.
  final String sessionId;

  /// The relay URL from the pairing URI.
  final String relayUrl;

  /// The tool name reported by the host (e.g. "claude-code"), if known.
  final String? toolName;

  /// When this session was first connected.
  final DateTime connectedAt;

  /// When this session was last active (connected or disconnected).
  final DateTime lastActiveAt;

  /// How the session ended.
  final SessionEndReason endReason;

  SessionRecord({
    required this.pairingUri,
    required this.sessionId,
    required this.relayUrl,
    this.toolName,
    required this.connectedAt,
    required this.lastActiveAt,
    this.endReason = SessionEndReason.unknown,
  });

  /// Create a new record from a pairing URI (initial connection).
  factory SessionRecord.fromPairing(PairingUri pairing) {
    final now = DateTime.now();
    return SessionRecord(
      pairingUri: pairing.build(),
      sessionId: pairing.sessionId,
      relayUrl: pairing.relayUrl,
      connectedAt: now,
      lastActiveAt: now,
    );
  }

  SessionRecord copyWith({
    String? toolName,
    DateTime? lastActiveAt,
    SessionEndReason? endReason,
  }) {
    return SessionRecord(
      pairingUri: pairingUri,
      sessionId: sessionId,
      relayUrl: relayUrl,
      toolName: toolName ?? this.toolName,
      connectedAt: connectedAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      endReason: endReason ?? this.endReason,
    );
  }

  Map<String, dynamic> toJson() => {
    'pairingUri': pairingUri,
    'sessionId': sessionId,
    'relayUrl': relayUrl,
    'toolName': toolName,
    'connectedAt': connectedAt.toIso8601String(),
    'lastActiveAt': lastActiveAt.toIso8601String(),
    'endReason': endReason.name,
  };

  factory SessionRecord.fromJson(Map<String, dynamic> json) {
    return SessionRecord(
      pairingUri: json['pairingUri'] as String,
      sessionId: json['sessionId'] as String,
      relayUrl: json['relayUrl'] as String,
      toolName: json['toolName'] as String?,
      connectedAt: DateTime.parse(json['connectedAt'] as String),
      lastActiveAt: DateTime.parse(json['lastActiveAt'] as String),
      endReason: SessionEndReason.values.firstWhere(
        (e) => e.name == json['endReason'],
        orElse: () => SessionEndReason.unknown,
      ),
    );
  }

  /// Short display label: tool name or truncated session ID.
  String get displayName {
    if (toolName != null && toolName!.isNotEmpty) return toolName!;
    if (sessionId.length > 12) return sessionId.substring(0, 12);
    return sessionId;
  }
}

enum SessionEndReason {
  /// Still connected or unknown.
  unknown,

  /// User intentionally disconnected from the app.
  userDisconnected,

  /// Host ended the session (process exited).
  hostEnded,

  /// Connection lost (network error, relay error).
  connectionLost,
}
