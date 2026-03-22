import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_relay_app/core/crypto.dart';
import 'package:terminal_relay_app/core/protocol.dart';

Map<String, dynamic> loadVectors() {
  final file = File('test/fixtures/rust_test_vectors.json');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

Uint8List hexToBytes(String hex) {
  final bytes = <int>[];
  for (var i = 0; i < hex.length; i += 2) {
    bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
  }
  return Uint8List.fromList(bytes);
}

String bytesToHex(Uint8List bytes) {
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

void main() {
  late Map<String, dynamic> crypto;

  setUpAll(() {
    final vectors = loadVectors();
    crypto = vectors['crypto'] as Map<String, dynamic>;
  });

  // ---------------------------------------------------------------------------
  // Key derivation
  // ---------------------------------------------------------------------------

  group('Key derivation matches Rust', () {
    test('host derives same keys as Rust', () async {
      final hostSecret = hexToBytes(crypto['host_secret'] as String);
      final clientPublic = hexToBytes(crypto['client_public'] as String);
      final sessionId = crypto['session_id'] as String;

      final keys = await deriveSessionKeys(
        role: PeerRole.host,
        sessionId: sessionId,
        localSecret: hostSecret,
        remotePublic: clientPublic,
      );

      expect(bytesToHex(keys.tx), crypto['host_tx_key']);
      expect(bytesToHex(keys.rx), crypto['host_rx_key']);
    });

    test('client derives same keys as Rust', () async {
      final clientSecret = hexToBytes(crypto['client_secret'] as String);
      final hostPublic = hexToBytes(crypto['host_public'] as String);
      final sessionId = crypto['session_id'] as String;

      final keys = await deriveSessionKeys(
        role: PeerRole.client,
        sessionId: sessionId,
        localSecret: clientSecret,
        remotePublic: hostPublic,
      );

      expect(bytesToHex(keys.tx), crypto['client_tx_key']);
      expect(bytesToHex(keys.rx), crypto['client_rx_key']);
    });

    test('host TX = client RX and vice versa', () async {
      final hostSecret = hexToBytes(crypto['host_secret'] as String);
      final clientSecret = hexToBytes(crypto['client_secret'] as String);
      final hostPublic = hexToBytes(crypto['host_public'] as String);
      final clientPublic = hexToBytes(crypto['client_public'] as String);
      final sessionId = crypto['session_id'] as String;

      final hostKeys = await deriveSessionKeys(
        role: PeerRole.host,
        sessionId: sessionId,
        localSecret: hostSecret,
        remotePublic: clientPublic,
      );

      final clientKeys = await deriveSessionKeys(
        role: PeerRole.client,
        sessionId: sessionId,
        localSecret: clientSecret,
        remotePublic: hostPublic,
      );

      expect(bytesToHex(hostKeys.tx), bytesToHex(clientKeys.rx));
      expect(bytesToHex(hostKeys.rx), bytesToHex(clientKeys.tx));
    });
  });

  // ---------------------------------------------------------------------------
  // Fingerprint
  // ---------------------------------------------------------------------------

  group('Fingerprint matches Rust', () {
    test('host fingerprint matches', () async {
      final hostPublic = hexToBytes(crypto['host_public'] as String);
      final fp = await fingerprint(hostPublic);
      expect(fp, crypto['host_fingerprint']);
    });

    test('client fingerprint matches', () async {
      final clientPublic = hexToBytes(crypto['client_public'] as String);
      final fp = await fingerprint(clientPublic);
      expect(fp, crypto['client_fingerprint']);
    });
  });

  // ---------------------------------------------------------------------------
  // Handshake MAC
  // ---------------------------------------------------------------------------

  group('Handshake MAC matches Rust', () {
    test('host MAC matches', () async {
      final hostTxKey = hexToBytes(crypto['host_tx_key'] as String);
      final hostPublic = hexToBytes(crypto['host_public'] as String);
      final clientPublic = hexToBytes(crypto['client_public'] as String);
      final sessionId = crypto['session_id'] as String;

      final mac = await computeHandshakeMac(
        txKey: hostTxKey,
        localPublic: hostPublic,
        remotePublic: clientPublic,
        sessionId: sessionId,
      );

      expect(bytesToHex(mac), crypto['host_handshake_mac']);
    });

    test('client MAC matches', () async {
      final clientTxKey = hexToBytes(crypto['client_tx_key'] as String);
      final clientPublic = hexToBytes(crypto['client_public'] as String);
      final hostPublic = hexToBytes(crypto['host_public'] as String);
      final sessionId = crypto['session_id'] as String;

      final mac = await computeHandshakeMac(
        txKey: clientTxKey,
        localPublic: clientPublic,
        remotePublic: hostPublic,
        sessionId: sessionId,
      );

      expect(bytesToHex(mac), crypto['client_handshake_mac']);
    });

    test('host MAC verifies with client RX key', () async {
      final clientRxKey = hexToBytes(crypto['client_rx_key'] as String);
      final hostPublic = hexToBytes(crypto['host_public'] as String);
      final clientPublic = hexToBytes(crypto['client_public'] as String);
      final sessionId = crypto['session_id'] as String;
      final hostMac = hexToBytes(crypto['host_handshake_mac'] as String);

      final ok = await verifyHandshakeMac(
        rxKey: clientRxKey,
        remotePublic: hostPublic,
        localPublic: clientPublic,
        sessionId: sessionId,
        receivedMac: hostMac,
      );

      expect(ok, true);
    });

    test('tampered MAC fails verification', () async {
      final clientRxKey = hexToBytes(crypto['client_rx_key'] as String);
      final hostPublic = hexToBytes(crypto['host_public'] as String);
      final clientPublic = hexToBytes(crypto['client_public'] as String);
      final sessionId = crypto['session_id'] as String;
      final hostMac = hexToBytes(crypto['host_handshake_mac'] as String);

      // Tamper with one byte
      hostMac[0] ^= 0xff;

      final ok = await verifyHandshakeMac(
        rxKey: clientRxKey,
        remotePublic: hostPublic,
        localPublic: clientPublic,
        sessionId: sessionId,
        receivedMac: hostMac,
      );

      expect(ok, false);
    });
  });

  // ---------------------------------------------------------------------------
  // AES-256-GCM encryption
  // ---------------------------------------------------------------------------

  group('AES-256-GCM matches Rust', () {
    test('decrypt Rust ciphertext', () async {
      final sealTest = crypto['seal_test'] as Map<String, dynamic>;
      final hostTxKey = hexToBytes(crypto['host_tx_key'] as String);
      final ciphertext = hexToBytes(sealTest['ciphertext'] as String);
      final _ = hexToBytes(sealTest['plaintext'] as String); // verified via decrypt
      final nonce = sealTest['nonce'] as int;

      // Use SecureChannel to decrypt
      // Host TX key = Client RX key, so create a client channel
      final clientRxKey = hexToBytes(crypto['client_rx_key'] as String);
      final clientTxKey = hexToBytes(crypto['client_tx_key'] as String);

      // Verify host_tx == client_rx
      expect(bytesToHex(hostTxKey), bytesToHex(clientRxKey));

      final channel = SecureChannel(SessionKeys(
        tx: clientTxKey,
        rx: clientRxKey,
      ));

      final sealed = SealedFrame(nonce: nonce, ciphertext: ciphertext);
      final msg = await channel.open(sealed);

      // The plaintext is an encoded SecureMessage::PtyOutput("test data")
      expect(msg, isA<PtyOutput>());
      expect(utf8.decode((msg as PtyOutput).data), 'test data');
    });

    test('seal then open round-trip', () async {
      final hostTxKey = hexToBytes(crypto['host_tx_key'] as String);
      final hostRxKey = hexToBytes(crypto['host_rx_key'] as String);
      final clientTxKey = hexToBytes(crypto['client_tx_key'] as String);
      final clientRxKey = hexToBytes(crypto['client_rx_key'] as String);

      final hostChannel = SecureChannel(SessionKeys(tx: hostTxKey, rx: hostRxKey));
      final clientChannel = SecureChannel(SessionKeys(tx: clientTxKey, rx: clientRxKey));

      // Host -> Client
      final sealed = await hostChannel.seal(PtyOutput(Uint8List.fromList(utf8.encode('hello from host'))));
      final opened = await clientChannel.open(sealed);
      expect(opened, isA<PtyOutput>());
      expect(utf8.decode((opened as PtyOutput).data), 'hello from host');

      // Client -> Host
      final sealed2 = await clientChannel.seal(PtyInput(Uint8List.fromList(utf8.encode('hello from client'))));
      final opened2 = await hostChannel.open(sealed2);
      expect(opened2, isA<PtyInput>());
      expect(utf8.decode((opened2 as PtyInput).data), 'hello from client');
    });

    test('replay detection', () async {
      final hostTxKey = hexToBytes(crypto['host_tx_key'] as String);
      final hostRxKey = hexToBytes(crypto['host_rx_key'] as String);
      final clientTxKey = hexToBytes(crypto['client_tx_key'] as String);
      final clientRxKey = hexToBytes(crypto['client_rx_key'] as String);

      final hostChannel = SecureChannel(SessionKeys(tx: hostTxKey, rx: hostRxKey));
      final clientChannel = SecureChannel(SessionKeys(tx: clientTxKey, rx: clientRxKey));

      final sealed = await hostChannel.seal(Heartbeat());
      await clientChannel.open(sealed);

      // Replaying the same frame should fail
      expect(
        () => clientChannel.open(sealed),
        throwsA(isA<StateError>()),
      );
    });

    test('nonces increment', () async {
      final hostTxKey = hexToBytes(crypto['host_tx_key'] as String);
      final hostRxKey = hexToBytes(crypto['host_rx_key'] as String);

      final channel = SecureChannel(SessionKeys(tx: hostTxKey, rx: hostRxKey));

      for (var i = 0; i < 5; i++) {
        final sealed = await channel.seal(Heartbeat());
        expect(sealed.nonce, i);
      }
    });
  });
}
