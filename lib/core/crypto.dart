import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

import 'protocol.dart';

/// Maximum allowed age for a handshake timestamp (5 minutes).
const int handshakeMaxAgeMs = 5 * 60 * 1000;

// ---------------------------------------------------------------------------
// Key pair
// ---------------------------------------------------------------------------

class RelayKeyPair {
  final Uint8List secret; // 32 bytes
  final Uint8List public_; // 32 bytes

  RelayKeyPair({required this.secret, required this.public_});
}

/// Derived per-session TX/RX symmetric keys.
class SessionKeys {
  final Uint8List tx; // 32 bytes
  final Uint8List rx; // 32 bytes

  SessionKeys({required this.tx, required this.rx});
}

// ---------------------------------------------------------------------------
// Key generation
// ---------------------------------------------------------------------------

final _x25519 = X25519();

Future<RelayKeyPair> generateKeyPair() async {
  final kp = await _x25519.newKeyPair();
  final secretBytes = await kp.extractPrivateKeyBytes();
  final publicKey = await kp.extractPublicKey();
  return RelayKeyPair(
    secret: Uint8List.fromList(secretBytes),
    public_: Uint8List.fromList(publicKey.bytes),
  );
}

// ---------------------------------------------------------------------------
// Key derivation (must match Rust: HKDF-SHA256, salt=session_id, info=label)
// ---------------------------------------------------------------------------

Future<SessionKeys> deriveSessionKeys({
  required PeerRole role,
  required String sessionId,
  required Uint8List localSecret,
  required Uint8List remotePublic,
}) async {
  // Perform X25519 DH
  final localKeyPair = await _x25519.newKeyPairFromSeed(localSecret);
  final remoteKey = SimplePublicKey(remotePublic, type: KeyPairType.x25519);
  final shared = await _x25519.sharedSecretKey(
    keyPair: localKeyPair,
    remotePublicKey: remoteKey,
  );
  final sharedBytes = await shared.extractBytes();

  // HKDF-SHA256: salt = session_id bytes, info = label, output = 64 bytes
  final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 64);
  final derivedKey = await hkdf.deriveKey(
    secretKey: SecretKey(sharedBytes),
    nonce: sessionId.codeUnits, // salt
    info: 'farwatch/v1/channel-keys'.codeUnits,
  );
  final okm = await derivedKey.extractBytes();

  final first = Uint8List.fromList(okm.sublist(0, 32));
  final second = Uint8List.fromList(okm.sublist(32, 64));

  return switch (role) {
    PeerRole.host => SessionKeys(tx: first, rx: second),
    PeerRole.client => SessionKeys(tx: second, rx: first),
  };
}

// ---------------------------------------------------------------------------
// Fingerprint: SHA-256 of public key, first 8 bytes as hex
// ---------------------------------------------------------------------------

Future<String> fingerprint(Uint8List publicKey) async {
  final sha256 = Sha256();
  final hash = await sha256.hash(publicKey);
  final first8 = hash.bytes.sublist(0, 8);
  return first8.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

// ---------------------------------------------------------------------------
// Handshake MAC (HMAC-SHA256)
//
// Transcript: local_public || remote_public || session_id
// ---------------------------------------------------------------------------

Future<Uint8List> computeHandshakeMac({
  required Uint8List txKey,
  required Uint8List localPublic,
  required Uint8List remotePublic,
  required String sessionId,
}) async {
  final hmac = Hmac.sha256();
  final transcript = <int>[
    ...localPublic,
    ...remotePublic,
    ...sessionId.codeUnits,
  ];
  final mac = await hmac.calculateMac(transcript, secretKey: SecretKey(txKey));
  return Uint8List.fromList(mac.bytes);
}

Future<bool> verifyHandshakeMac({
  required Uint8List rxKey,
  required Uint8List remotePublic,
  required Uint8List localPublic,
  required String sessionId,
  required Uint8List receivedMac,
}) async {
  final expected = await computeHandshakeMac(
    txKey: rxKey,
    localPublic: remotePublic,
    remotePublic: localPublic,
    sessionId: sessionId,
  );
  return constantTimeMacEqual(expected, receivedMac);
}

// ---------------------------------------------------------------------------
// Constant-time MAC comparison
// ---------------------------------------------------------------------------

/// Constant-time comparison of two MACs. Returns true if equal.
/// Does not short-circuit on the first differing byte.
bool constantTimeMacEqual(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}

// ---------------------------------------------------------------------------
// Key material cleanup
// ---------------------------------------------------------------------------

/// Overwrite a byte buffer with zeros to clear sensitive key material.
void zeroOut(Uint8List? bytes) {
  if (bytes == null) return;
  bytes.fillRange(0, bytes.length, 0);
}

// ---------------------------------------------------------------------------
// SecureChannel: encrypt/decrypt with AES-256-GCM + sequential nonces
// ---------------------------------------------------------------------------

class SecureChannel {
  final Uint8List _txKey;
  final Uint8List _rxKey;
  int _txNonce = 0;
  int? _lastRxNonce;

  SecureChannel(SessionKeys keys) : _txKey = keys.tx, _rxKey = keys.rx;

  /// Zero out key material when the channel is no longer needed.
  void dispose() {
    zeroOut(_txKey);
    zeroOut(_rxKey);
  }

  /// Encrypt a SecureMessage into a SealedFrame.
  Future<SealedFrame> seal(SecureMessage message) async {
    final plaintext = encodeSecureMessage(message);
    final nonce = _txNonce;
    _txNonce++;

    final ciphertext = await _encrypt(_txKey, nonce, plaintext);
    return SealedFrame(nonce: nonce, ciphertext: ciphertext);
  }

  /// Decrypt a SealedFrame into a SecureMessage.
  Future<SecureMessage> open(SealedFrame frame) async {
    if (_lastRxNonce != null && frame.nonce <= _lastRxNonce!) {
      throw StateError(
        'Replay detected: nonce ${frame.nonce} <= $_lastRxNonce',
      );
    }

    final plaintext = await _decrypt(_rxKey, frame.nonce, frame.ciphertext);
    _lastRxNonce = frame.nonce;
    return decodeSecureMessage(plaintext);
  }
}

// ---------------------------------------------------------------------------
// AES-256-GCM helpers
//
// Nonce layout (12 bytes): [0,0,0,0, counter_be_8_bytes]
// Must match Rust's nonce_from_counter().
// ---------------------------------------------------------------------------

final _aesGcm = AesGcm.with256bits(nonceLength: 12);

Uint8List _nonceFromCounter(int counter) {
  final nonce = Uint8List(12);
  // Big-endian counter in bytes 4..12
  final bd = ByteData.sublistView(nonce);
  bd.setUint64(4, counter);
  return nonce;
}

Future<Uint8List> _encrypt(
  Uint8List key,
  int counter,
  Uint8List plaintext,
) async {
  final nonce = _nonceFromCounter(counter);
  final secretBox = await _aesGcm.encrypt(
    plaintext,
    secretKey: SecretKey(key),
    nonce: nonce,
  );
  // AES-GCM output: ciphertext || MAC (16 bytes)
  return Uint8List.fromList(secretBox.concatenation(nonce: false));
}

Future<Uint8List> _decrypt(
  Uint8List key,
  int counter,
  Uint8List ciphertext,
) async {
  final nonce = _nonceFromCounter(counter);
  // Split ciphertext into actual ciphertext + MAC (last 16 bytes)
  if (ciphertext.length < 16) {
    throw StateError('Ciphertext too short');
  }
  final ct = ciphertext.sublist(0, ciphertext.length - 16);
  final mac = Mac(ciphertext.sublist(ciphertext.length - 16));

  final secretBox = SecretBox(ct, nonce: nonce, mac: mac);
  final plaintext = await _aesGcm.decrypt(secretBox, secretKey: SecretKey(key));
  return Uint8List.fromList(plaintext);
}
