import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/crypto.dart';
import '../core/pairing.dart';
import '../core/protocol.dart';
import 'relay_client.dart';

/// Session states for the UI.
enum SessionState {
  disconnected,
  connecting,
  waitingForPeer,
  handshaking,
  connected,
  error,
}

/// Manages the full lifecycle of an attach session:
/// connect -> register -> handshake -> E2E encrypted channel.
class RelaySession extends ChangeNotifier {
  final PairingUri pairing;

  SessionState _state = SessionState.disconnected;
  SessionState get state => _state;

  String? _error;
  String? get error => _error;

  String? _toolName;
  String? get toolName => _toolName;

  RelayClient? _client;
  RelayKeyPair? _localKey;
  String? _localFingerprint;
  SecureChannel? _channel;
  bool _confirmed = false;
  Uint8List? _expectedPeerMac;
  HandshakeConfirm? _pendingConfirm;
  bool _handshakeInProgress = false;
  Timer? _heartbeatTimer;

  /// Stream of decrypted PtyOutput bytes for the terminal emulator.
  final StreamController<Uint8List> _outputController =
      StreamController<Uint8List>.broadcast();
  Stream<Uint8List> get output => _outputController.stream;

  /// Stream of session lifecycle events for the UI.
  final StreamController<SecureMessage> _eventController =
      StreamController<SecureMessage>.broadcast();
  Stream<SecureMessage> get events => _eventController.stream;

  RelaySession({required this.pairing});

  bool _disposed = false;

  void _setState(SessionState s) {
    debugPrint('[session] state: $s');
    _state = s;
    if (!_disposed) notifyListeners();
  }

  /// Connect to relay, register as Client, and begin handshake.
  Future<void> connect() async {
    try {
      _setState(SessionState.connecting);
      _error = null;

      // Generate ephemeral key pair
      _localKey = await generateKeyPair();
      _localFingerprint = await fingerprint(_localKey!.public_);
      debugPrint('[session] local fingerprint: $_localFingerprint');

      // Connect to relay
      _client = await RelayClient.connect(
        relayUrl: pairing.relayUrl,
        request: RegisterRequest(
          protocolVersion: protocolVersion,
          protocolVersionMin: protocolVersionMin,
          clientVersion: '0.1.0',
          sessionId: pairing.sessionId,
          pairingCode: pairing.pairingCode,
          role: PeerRole.client,
        ),
      );

      debugPrint('[session] registered, peer_online=${_client!.registered?.peerOnline}');

      // Start listening for messages (drains any buffered during registration)
      _client!.listen(
        onMessage: _handleMessage,
        onError: (e) {
          debugPrint('[session] stream error: $e');
          _error = e.toString();
          _setState(SessionState.error);
        },
        onDone: () {
          debugPrint('[session] stream done');
          if (_state != SessionState.disconnected) {
            _error = 'Connection lost';
            _setState(SessionState.error);
          }
        },
      );

      // Start heartbeat
      _heartbeatTimer = Timer.periodic(
        const Duration(seconds: 10),
        (_) => _client?.send(RelayPing(DateTime.now().millisecondsSinceEpoch)),
      );

      // If peer (host) is already online, send handshake immediately
      if (_client!.registered?.peerOnline == true) {
        _sendHandshake();
        _setState(SessionState.handshaking);
      } else {
        _setState(SessionState.waitingForPeer);
      }
    } catch (e, st) {
      debugPrint('[session] connect error: $e\n$st');
      _error = e.toString();
      _setState(SessionState.error);
    }
  }

  void _sendHandshake() {
    debugPrint('[session] sending handshake');
    _client?.sendHandshake(
      sessionId: pairing.sessionId,
      publicKey: _localKey!.public_,
      fingerprint: _localFingerprint!,
      toolName: 'terminal-relay-app',
    );
  }

  void _handleMessage(RelayMessage msg) {
    debugPrint('[session] received: ${msg.runtimeType}');
    switch (msg) {
      case RelayRouteMsg(route: final route):
        if (route.sessionId != pairing.sessionId) return;
        _handleRoute(route);

      case RelayPeerStatus(status: final status):
        debugPrint('[session] peer status: role=${status.role}, online=${status.online}');
        if (status.role == PeerRole.host) {
          if (status.online) {
            _sendHandshake();
            _setState(SessionState.handshaking);
          } else {
            _error = 'Host went offline';
            _setState(SessionState.error);
          }
        }

      case RelayErrorMsg(error: final err):
        debugPrint('[session] relay error: ${err.message}');
        _error = err.message;
        _setState(SessionState.error);

      case RelayPing() || RelayPong() || RelayRegistered() || RelayRegister():
        break;
    }
  }

  Future<void> _handleRoute(RelayRoute route) async {
    final PeerFrame frame;
    try {
      frame = decodePeerFrame(route.payload);
      debugPrint('[session] decoded peer frame: ${frame.runtimeType}');
    } catch (e, st) {
      debugPrint('[session] failed to decode peer frame: $e\n$st');
      return;
    }

    try {
      switch (frame) {
        case PeerFrameHandshake(handshake: final h):
          await _handleHandshake(h);

        case PeerFrameHandshakeConfirm(confirm: final c):
          if (_handshakeInProgress) {
            debugPrint('[session] buffering HandshakeConfirm (handshake in progress)');
            _pendingConfirm = c;
          } else {
            _handleConfirm(c);
          }

        case PeerFrameSecure(frame: final sealed):
          await _handleSecure(sealed);

        case PeerFrameKeepAlive():
          break;
      }
    } catch (e, st) {
      debugPrint('[session] error handling ${frame.runtimeType}: $e\n$st');
    }
  }

  Future<void> _handleHandshake(Handshake handshake) async {
    debugPrint('[session] handshake from peer: fingerprint=${handshake.fingerprint}, '
        'tool=${handshake.toolName}, pubkey_len=${handshake.publicKey.length}');

    // Validate timestamp
    final now = DateTime.now().millisecondsSinceEpoch;
    final age = now - handshake.timestampMs;
    debugPrint('[session] handshake age: ${age}ms');
    if (age > handshakeMaxAgeMs || age < -handshakeMaxAgeMs) {
      debugPrint('[session] rejecting stale handshake');
      return;
    }

    // Validate fingerprint if expected
    if (pairing.expectedFingerprint != null &&
        handshake.fingerprint != pairing.expectedFingerprint) {
      _error = 'Fingerprint mismatch: expected ${pairing.expectedFingerprint}, '
          'got ${handshake.fingerprint}';
      _setState(SessionState.error);
      return;
    }

    _toolName = handshake.toolName;
    _handshakeInProgress = true;
    _pendingConfirm = null;

    // Derive session keys
    debugPrint('[session] deriving session keys...');
    final keys = await deriveSessionKeys(
      role: PeerRole.client,
      sessionId: pairing.sessionId,
      localSecret: _localKey!.secret,
      remotePublic: handshake.publicKey,
    );
    debugPrint('[session] keys derived');

    // Compute confirmation MACs
    final ourMac = await computeHandshakeMac(
      txKey: keys.tx,
      localPublic: _localKey!.public_,
      remotePublic: handshake.publicKey,
      sessionId: pairing.sessionId,
    );
    final peerMac = await computeHandshakeMac(
      txKey: keys.rx,
      localPublic: handshake.publicKey,
      remotePublic: _localKey!.public_,
      sessionId: pairing.sessionId,
    );

    _channel = SecureChannel(keys);
    _confirmed = false;
    _expectedPeerMac = peerMac;
    _handshakeInProgress = false;

    // Send our confirmation
    debugPrint('[session] sending HandshakeConfirm');
    _client?.sendPeerFrame(
      pairing.sessionId,
      PeerFrameHandshakeConfirm(HandshakeConfirm(mac: ourMac)),
    );

    _setState(SessionState.handshaking);

    // Process any HandshakeConfirm that arrived while we were deriving keys
    if (_pendingConfirm != null) {
      debugPrint('[session] processing buffered HandshakeConfirm');
      _handleConfirm(_pendingConfirm!);
      _pendingConfirm = null;
    }
  }

  void _handleConfirm(HandshakeConfirm confirm) {
    debugPrint('[session] received HandshakeConfirm, mac_len=${confirm.mac.length}');
    if (_expectedPeerMac == null) {
      debugPrint('[session] no expected MAC, ignoring');
      return;
    }

    // Constant-time compare
    var diff = 0;
    for (var i = 0; i < 32; i++) {
      diff |= confirm.mac[i] ^ _expectedPeerMac![i];
    }
    if (diff != 0) {
      debugPrint('[session] MAC mismatch!');
      _error = 'Handshake MAC mismatch';
      _channel = null;
      _confirmed = false;
      _expectedPeerMac = null;
      _setState(SessionState.error);
      return;
    }

    debugPrint('[session] handshake confirmed! Channel trusted.');
    _confirmed = true;
    _expectedPeerMac = null;
    _setState(SessionState.connected);
  }

  Future<void> _handleSecure(SealedFrame sealed) async {
    if (!_confirmed || _channel == null) return;

    try {
      final msg = await _channel!.open(sealed);
      switch (msg) {
        case PtyOutput(data: final bytes):
          _outputController.add(bytes);

        case SessionEnded():
          _eventController.add(msg);
          await disconnect();

        case VersionNotice() || ClipboardMsg() || ReadOnlyMsg():
          _eventController.add(msg);

        case PtyInput() || Resize() || Heartbeat() || UnknownMessage():
          break;
      }
    } catch (e) {
      debugPrint('[session] SecureChannel.open error: $e');
    }
  }

  /// Send keyboard input to the host.
  Future<void> sendInput(Uint8List data) async {
    if (!_confirmed || _channel == null) return;
    final sealed = await _channel!.seal(PtyInput(data));
    _client?.sendPeerFrame(pairing.sessionId, PeerFrameSecure(sealed));
  }

  /// Send terminal resize to the host.
  Future<void> sendResize(int cols, int rows) async {
    if (!_confirmed || _channel == null) return;
    final sealed = await _channel!.seal(Resize(cols: cols, rows: rows));
    _client?.sendPeerFrame(pairing.sessionId, PeerFrameSecure(sealed));
  }

  /// Disconnect and clean up.
  Future<void> disconnect() async {
    _heartbeatTimer?.cancel();

    // Send SessionEnded to the host before closing
    if (_confirmed && _channel != null && _client != null) {
      try {
        final sealed = await _channel!.seal(SessionEnded(0));
        _client!.sendPeerFrame(pairing.sessionId, PeerFrameSecure(sealed));
        // Brief delay to let the message flush through the WebSocket
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (_) {}
    }

    await _client?.close();
    _channel = null;
    _confirmed = false;
    _expectedPeerMac = null;
    _setState(SessionState.disconnected);
  }

  @override
  void dispose() {
    _disposed = true;
    disconnect();
    _outputController.close();
    _eventController.close();
    super.dispose();
  }
}
