import 'dart:typed_data';
import 'package:msgpack_dart/msgpack_dart.dart' as msgpack;

/// Current protocol version. Must match the Rust server.
const int protocolVersion = 2;
const int protocolVersionMin = 1;

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

enum PeerRole {
  host,
  client;

  /// MessagePack encodes Rust enums as {variant_name: null} for unit variants.
  /// serde serializes enum variants by name.
  Map<String, dynamic> toMsgpack() => {name[0].toUpperCase() + name.substring(1): null};

  static PeerRole fromMsgpack(dynamic v) {
    if (v is Map) {
      if (v.containsKey('Host')) return PeerRole.host;
      if (v.containsKey('Client')) return PeerRole.client;
    }
    if (v is String) {
      if (v == 'Host') return PeerRole.host;
      if (v == 'Client') return PeerRole.client;
    }
    throw FormatException('Unknown PeerRole: $v');
  }
}

// ---------------------------------------------------------------------------
// Relay layer messages
// ---------------------------------------------------------------------------

class RegisterRequest {
  final int protocolVersion;
  final int? protocolVersionMin;
  final String clientVersion;
  final String sessionId;
  final String pairingCode;
  final PeerRole role;
  final String? resumeToken;

  RegisterRequest({
    required this.protocolVersion,
    this.protocolVersionMin,
    required this.clientVersion,
    required this.sessionId,
    required this.pairingCode,
    required this.role,
    this.resumeToken,
  });

  Map<String, dynamic> toMap() => {
    'protocol_version': protocolVersion,
    'protocol_version_min': protocolVersionMin,
    'client_version': clientVersion,
    'session_id': sessionId,
    'pairing_code': pairingCode,
    'role': role.toMsgpack(),
    'resume_token': resumeToken,
  };
}

class RegisterResponse {
  final String serverVersion;
  final int negotiatedProtocolVersion;
  final String resumeToken;
  final bool peerOnline;
  final int sessionTtlSecs;

  RegisterResponse({
    required this.serverVersion,
    required this.negotiatedProtocolVersion,
    required this.resumeToken,
    required this.peerOnline,
    required this.sessionTtlSecs,
  });

  factory RegisterResponse.fromMap(Map m) => RegisterResponse(
    serverVersion: m['server_version'] as String,
    negotiatedProtocolVersion: m['negotiated_protocol_version'] as int,
    resumeToken: m['resume_token'] as String,
    peerOnline: m['peer_online'] as bool,
    sessionTtlSecs: m['session_ttl_secs'] as int,
  );
}

class RelayRoute {
  final String sessionId;
  final Uint8List payload;

  RelayRoute({required this.sessionId, required this.payload});

  Map<String, dynamic> toMap() => {
    'session_id': sessionId,
    'payload': payload,
  };

  factory RelayRoute.fromMap(Map m) => RelayRoute(
    sessionId: m['session_id'] as String,
    payload: _toUint8List(m['payload']),
  );
}

class PeerStatus {
  final String sessionId;
  final PeerRole role;
  final bool online;

  PeerStatus({required this.sessionId, required this.role, required this.online});

  factory PeerStatus.fromMap(Map m) => PeerStatus(
    sessionId: m['session_id'] as String,
    role: PeerRole.fromMsgpack(m['role']),
    online: m['online'] as bool,
  );
}

class RelayError {
  final String message;
  RelayError({required this.message});

  factory RelayError.fromMap(Map m) => RelayError(message: m['message'] as String);
}

// ---------------------------------------------------------------------------
// RelayMessage (tagged enum)
//
// Rust serde serializes enums as {"VariantName": <inner>}.
// Unit variants like Ping(u64) become {"Ping": 42}.
// ---------------------------------------------------------------------------

sealed class RelayMessage {
  Map<String, dynamic> encode();
}

class RelayRegister extends RelayMessage {
  final RegisterRequest request;
  RelayRegister(this.request);

  @override
  Map<String, dynamic> encode() => {'Register': request.toMap()};
}

class RelayRegistered extends RelayMessage {
  final RegisterResponse response;
  RelayRegistered(this.response);

  @override
  Map<String, dynamic> encode() => {'Registered': response};

  factory RelayRegistered.fromValue(dynamic v) =>
      RelayRegistered(RegisterResponse.fromMap(v as Map));
}

class RelayRouteMsg extends RelayMessage {
  final RelayRoute route;
  RelayRouteMsg(this.route);

  @override
  Map<String, dynamic> encode() => {'Route': route.toMap()};

  factory RelayRouteMsg.fromValue(dynamic v) =>
      RelayRouteMsg(RelayRoute.fromMap(v as Map));
}

class RelayPeerStatus extends RelayMessage {
  final PeerStatus status;
  RelayPeerStatus(this.status);

  @override
  Map<String, dynamic> encode() => {'PeerStatus': status};

  factory RelayPeerStatus.fromValue(dynamic v) =>
      RelayPeerStatus(PeerStatus.fromMap(v as Map));
}

class RelayPing extends RelayMessage {
  final int timestamp;
  RelayPing(this.timestamp);

  @override
  Map<String, dynamic> encode() => {'Ping': timestamp};
}

class RelayPong extends RelayMessage {
  final int timestamp;
  RelayPong(this.timestamp);

  @override
  Map<String, dynamic> encode() => {'Pong': timestamp};
}

/// Unknown relay message variant — for forward compatibility.
/// Silently ignored by the client.
class RelayUnknown extends RelayMessage {
  final String variant;
  RelayUnknown(this.variant);

  @override
  Map<String, dynamic> encode() => {'Unknown': variant};
}

class RelayErrorMsg extends RelayMessage {
  final RelayError error;
  RelayErrorMsg(this.error);

  @override
  Map<String, dynamic> encode() => {'Error': error};

  factory RelayErrorMsg.fromValue(dynamic v) =>
      RelayErrorMsg(RelayError.fromMap(v as Map));
}

// ---------------------------------------------------------------------------
// Peer-to-peer frames (inside Route payloads)
// ---------------------------------------------------------------------------

class Handshake {
  final Uint8List publicKey; // 32 bytes
  final String fingerprint;
  final String? toolName;
  final int timestampMs;

  Handshake({
    required this.publicKey,
    required this.fingerprint,
    this.toolName,
    required this.timestampMs,
  });

  Map<String, dynamic> toMap() => {
    'public_key': publicKey,
    'fingerprint': fingerprint,
    'tool_name': toolName,
    'timestamp_ms': timestampMs,
  };

  factory Handshake.fromMap(Map m) => Handshake(
    publicKey: _toUint8List(m['public_key']),
    fingerprint: m['fingerprint'] as String,
    toolName: m['tool_name'] as String?,
    timestampMs: m['timestamp_ms'] as int,
  );
}

class SealedFrame {
  final int nonce;
  final Uint8List ciphertext;

  SealedFrame({required this.nonce, required this.ciphertext});

  Map<String, dynamic> toMap() => {
    'nonce': nonce,
    'ciphertext': ciphertext,
  };

  factory SealedFrame.fromMap(Map m) => SealedFrame(
    nonce: m['nonce'] as int,
    ciphertext: _toUint8List(m['ciphertext']),
  );
}

class HandshakeConfirm {
  final Uint8List mac; // 32 bytes

  HandshakeConfirm({required this.mac});

  Map<String, dynamic> toMap() => {'mac': mac};

  factory HandshakeConfirm.fromMap(Map m) => HandshakeConfirm(
    mac: _toUint8List(m['mac']),
  );
}

sealed class PeerFrame {}

class PeerFrameHandshake extends PeerFrame {
  final Handshake handshake;
  PeerFrameHandshake(this.handshake);
}

class PeerFrameHandshakeConfirm extends PeerFrame {
  final HandshakeConfirm confirm;
  PeerFrameHandshakeConfirm(this.confirm);
}

class PeerFrameSecure extends PeerFrame {
  final SealedFrame frame;
  PeerFrameSecure(this.frame);
}

class PeerFrameKeepAlive extends PeerFrame {}

/// Unknown peer frame variant — for forward compatibility.
class PeerFrameUnknown extends PeerFrame {}

// ---------------------------------------------------------------------------
// SecureMessage (inner encrypted payload)
// ---------------------------------------------------------------------------

sealed class SecureMessage {}

class PtyInput extends SecureMessage {
  final Uint8List data;
  PtyInput(this.data);
}

class PtyOutput extends SecureMessage {
  final Uint8List data;
  PtyOutput(this.data);
}

class Resize extends SecureMessage {
  final int cols;
  final int rows;
  Resize({required this.cols, required this.rows});
}

class Heartbeat extends SecureMessage {}

class VersionNotice extends SecureMessage {
  final String minimumVersion;
  VersionNotice(this.minimumVersion);
}

class SessionEnded extends SecureMessage {
  final int exitCode;
  SessionEnded(this.exitCode);
}

class ClipboardMsg extends SecureMessage {
  final String content;
  ClipboardMsg(this.content);
}

class ReadOnlyMsg extends SecureMessage {
  final bool enabled;
  ReadOnlyMsg(this.enabled);
}

class VoiceCommand extends SecureMessage {
  final String transcript;
  final String? intent;
  final double confidence;
  VoiceCommand({required this.transcript, this.intent, required this.confidence});
}

class UnknownMessage extends SecureMessage {
  final Uint8List raw;
  UnknownMessage(this.raw);
}

// ---------------------------------------------------------------------------
// Encoding / Decoding
// ---------------------------------------------------------------------------

Uint8List encodeRelay(RelayMessage msg) {
  return msgpack.serialize(msg.encode());
}

RelayMessage decodeRelay(Uint8List bytes) {
  final decoded = msgpack.deserialize(bytes);
  if (decoded is! Map) throw FormatException('Expected map, got ${decoded.runtimeType}');

  final entry = decoded.entries.first;
  final key = entry.key as String;
  final value = entry.value;

  return switch (key) {
    'Register'   => throw UnsupportedError('Client should not receive Register'),
    'Registered' => RelayRegistered.fromValue(value),
    'Route'      => RelayRouteMsg.fromValue(value),
    'PeerStatus' => RelayPeerStatus.fromValue(value),
    'Ping'       => RelayPing(value as int),
    'Pong'       => RelayPong(value as int),
    'Error'      => RelayErrorMsg.fromValue(value),
    _            => RelayUnknown(key),
  };
}

Uint8List encodePeerFrame(PeerFrame frame) {
  // Unit variants are serialized as bare strings by Rust's rmp_serde.
  // Non-unit variants are serialized as {"VariantName": <inner>}.
  if (frame is PeerFrameKeepAlive) {
    return msgpack.serialize('KeepAlive');
  }
  final map = switch (frame) {
    PeerFrameHandshake(handshake: final h) => {'Handshake': h.toMap()},
    PeerFrameHandshakeConfirm(confirm: final c) => {'HandshakeConfirm': c.toMap()},
    PeerFrameSecure(frame: final f) => {'Secure': f.toMap()},
    PeerFrameKeepAlive() => throw StateError('unreachable'),
    PeerFrameUnknown() => throw StateError('cannot encode unknown frame'),
  };
  return msgpack.serialize(map);
}

PeerFrame decodePeerFrame(Uint8List bytes) {
  final decoded = msgpack.deserialize(bytes);

  // Unit variants are serialized as bare strings by Rust's rmp_serde.
  if (decoded is String) {
    return switch (decoded) {
      'KeepAlive' => PeerFrameKeepAlive(),
      _ => PeerFrameUnknown(),
    };
  }

  if (decoded is! Map) return PeerFrameUnknown();

  final entry = decoded.entries.first;
  final key = entry.key as String;
  final value = entry.value;

  return switch (key) {
    'Handshake'        => PeerFrameHandshake(Handshake.fromMap(value as Map)),
    'HandshakeConfirm' => PeerFrameHandshakeConfirm(HandshakeConfirm.fromMap(value as Map)),
    'Secure'           => PeerFrameSecure(SealedFrame.fromMap(value as Map)),
    'KeepAlive'        => PeerFrameKeepAlive(),
    _                  => PeerFrameUnknown(),
  };
}

Uint8List encodeSecureMessage(SecureMessage msg) {
  // Unit variants are serialized as bare strings by Rust's rmp_serde.
  if (msg is Heartbeat) {
    return msgpack.serialize('Heartbeat');
  }
  final map = switch (msg) {
    PtyInput(data: final d)                     => {'PtyInput': d},
    PtyOutput(data: final d)                    => {'PtyOutput': d},
    Resize(cols: final c, rows: final r)        => {'Resize': {'cols': c, 'rows': r}},
    Heartbeat()                                 => throw StateError('unreachable'),
    VersionNotice(minimumVersion: final v)      => {'VersionNotice': {'minimum_version': v}},
    SessionEnded(exitCode: final c)             => {'SessionEnded': {'exit_code': c}},
    ClipboardMsg(content: final c)              => {'Clipboard': {'content': c}},
    ReadOnlyMsg(enabled: final e)               => {'ReadOnly': {'enabled': e}},
    VoiceCommand(transcript: final t, intent: final i, confidence: final c) =>
      {'VoiceCommand': {'transcript': t, 'intent': i, 'confidence': c}},
    UnknownMessage(raw: final r)                => {'Unknown': r},
  };
  return msgpack.serialize(map);
}

SecureMessage decodeSecureMessage(Uint8List bytes) {
  try {
    final decoded = msgpack.deserialize(bytes);

    // Unit variants are serialized as bare strings by Rust's rmp_serde.
    if (decoded is String) {
      return switch (decoded) {
        'Heartbeat' => Heartbeat(),
        _ => UnknownMessage(bytes),
      };
    }

    if (decoded is! Map) return UnknownMessage(bytes);

    final entry = decoded.entries.first;
    final key = entry.key as String;
    final value = entry.value;

    return switch (key) {
      'PtyInput'       => PtyInput(_toUint8List(value)),
      'PtyOutput'      => PtyOutput(_toUint8List(value)),
      'Resize'         => Resize(cols: (value as Map)['cols'] as int, rows: value['rows'] as int),
      'Heartbeat'      => Heartbeat(),
      'VersionNotice'  => VersionNotice((value as Map)['minimum_version'] as String),
      'SessionEnded'   => SessionEnded((value as Map)['exit_code'] as int),
      'Clipboard'      => ClipboardMsg((value as Map)['content'] as String),
      'ReadOnly'       => ReadOnlyMsg((value as Map)['enabled'] as bool),
      'VoiceCommand'   => VoiceCommand(
                            transcript: (value as Map)['transcript'] as String,
                            intent: value['intent'] as String?,
                            confidence: (value['confidence'] as num).toDouble(),
                          ),
      _                => UnknownMessage(bytes),
    };
  } catch (_) {
    // Forward compatibility: unrecognized data becomes Unknown.
    return UnknownMessage(bytes);
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Uint8List _toUint8List(dynamic v) {
  if (v is Uint8List) return v;
  if (v is List) return Uint8List.fromList(v.cast<int>());
  throw FormatException('Expected byte list, got ${v.runtimeType}');
}
