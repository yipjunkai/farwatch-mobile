import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_relay_app/core/pairing.dart';

Map<String, dynamic> loadVectors() {
  final file = File('test/fixtures/rust_test_vectors.json');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  late Map<String, dynamic> pairingVectors;

  setUpAll(() {
    final vectors = loadVectors();
    pairingVectors = vectors['pairing'] as Map<String, dynamic>;
  });

  // ---------------------------------------------------------------------------
  // Parse Rust-generated URIs
  // ---------------------------------------------------------------------------

  group('Parse Rust-generated URIs', () {
    test('parses URI with fingerprint', () {
      final v = pairingVectors['with_fingerprint'] as Map<String, dynamic>;
      final uri = PairingUri.parse(v['uri'] as String);
      expect(uri.relayUrl, v['relay_url']);
      expect(uri.sessionId, v['session_id']);
      expect(uri.pairingCode, v['pairing_code']);
      expect(uri.expectedFingerprint, v['expected_fingerprint']);
    });

    test('parses URI without fingerprint', () {
      final v = pairingVectors['without_fingerprint'] as Map<String, dynamic>;
      final uri = PairingUri.parse(v['uri'] as String);
      expect(uri.relayUrl, v['relay_url']);
      expect(uri.sessionId, v['session_id']);
      expect(uri.pairingCode, v['pairing_code']);
      expect(uri.expectedFingerprint, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Round-trip
  // ---------------------------------------------------------------------------

  group('Dart build/parse round-trip', () {
    test('round-trips with fingerprint', () {
      final original = PairingUri(
        relayUrl: 'wss://relay.terminal-relay.dev/ws',
        sessionId: '550e8400-e29b-41d4-a716-446655440000',
        pairingCode: 'ABCDEF-GHIJKL-MNOPQR',
        expectedFingerprint: 'aaa8fff703b50b22',
      );
      final built = original.build();
      final parsed = PairingUri.parse(built);
      expect(parsed.relayUrl, original.relayUrl);
      expect(parsed.sessionId, original.sessionId);
      expect(parsed.pairingCode, original.pairingCode);
      expect(parsed.expectedFingerprint, original.expectedFingerprint);
    });

    test('round-trips without fingerprint', () {
      final original = PairingUri(
        relayUrl: 'ws://localhost:8080/ws',
        sessionId: 'test-session',
        pairingCode: 'ABC-DEF',
      );
      final built = original.build();
      final parsed = PairingUri.parse(built);
      expect(parsed.relayUrl, original.relayUrl);
      expect(parsed.sessionId, original.sessionId);
      expect(parsed.pairingCode, original.pairingCode);
      expect(parsed.expectedFingerprint, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Error cases
  // ---------------------------------------------------------------------------

  group('Error cases', () {
    test('rejects wrong scheme', () {
      expect(
        () => PairingUri.parse('https://pair?relay=x&session=y&code=z'),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects wrong host', () {
      expect(
        () => PairingUri.parse('termrelay://wrong?relay=x&session=y&code=z'),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects missing relay', () {
      expect(
        () => PairingUri.parse('termrelay://pair?session=y&code=z'),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects missing session', () {
      expect(
        () => PairingUri.parse('termrelay://pair?relay=x&code=z'),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects missing code', () {
      expect(
        () => PairingUri.parse('termrelay://pair?relay=x&session=y'),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects empty string', () {
      expect(
        () => PairingUri.parse(''),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects garbage', () {
      expect(
        () => PairingUri.parse('not a uri at all'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
