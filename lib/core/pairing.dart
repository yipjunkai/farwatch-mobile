// Pairing URI: termrelay://pair?relay=...&session=...&code=...&fingerprint=...

class PairingUri {
  final String relayUrl;
  final String sessionId;
  final String pairingCode;
  final String? expectedFingerprint;

  PairingUri({
    required this.relayUrl,
    required this.sessionId,
    required this.pairingCode,
    this.expectedFingerprint,
  });

  /// Build a termrelay:// URI string.
  String build() {
    final params = {
      'relay': relayUrl,
      'session': sessionId,
      'code': pairingCode,
      if (expectedFingerprint != null) 'fingerprint': expectedFingerprint,
    };
    final query = params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value as String)}')
        .join('&');
    return 'termrelay://pair?$query';
  }

  /// Parse a termrelay://pair?... URI string.
  static PairingUri parse(String input) {
    final uri = Uri.parse(input);
    if (uri.scheme != 'termrelay' || uri.host != 'pair') {
      throw FormatException('Invalid pairing URI scheme/host: $input');
    }

    final relay = uri.queryParameters['relay'];
    final session = uri.queryParameters['session'];
    final code = uri.queryParameters['code'];
    final fingerprint = uri.queryParameters['fingerprint'];

    if (relay == null || session == null || code == null) {
      throw FormatException('Missing required pairing URI parameters');
    }

    return PairingUri(
      relayUrl: relay,
      sessionId: session,
      pairingCode: code,
      expectedFingerprint: fingerprint,
    );
  }
}
