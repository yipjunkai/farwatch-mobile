import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../core/crypto.dart';
import '../core/pairing.dart';
import '../core/protocol.dart';
import 'relay_client.dart';

// ---------------------------------------------------------------------------
// Session state — explicit, no ambiguity
// ---------------------------------------------------------------------------

enum SessionState {
  /// Initial state, or after intentional disconnect.
  disconnected,

  /// WebSocket connecting + registering with relay.
  connecting,

  /// Registered with relay, waiting for host to come online.
  waitingForPeer,

  /// Key exchange in progress (deriving keys, computing MACs).
  handshaking,

  /// Keys derived, waiting for peer's HandshakeConfirm.
  awaitingConfirm,

  /// Fully authenticated E2E encrypted channel.
  connected,

  /// WebSocket lost, relay client is reconnecting.
  reconnecting,

  /// Unrecoverable error.
  error,
}

// ---------------------------------------------------------------------------
// RelaySession — the session state machine
// ---------------------------------------------------------------------------

class RelaySession extends ChangeNotifier {
  final PairingUri pairing;

  // State
  SessionState _state = SessionState.disconnected;
  SessionState get state => _state;
  String? _error;
  String? get error => _error;
  String? _toolName;
  String? get toolName => _toolName;
  bool _disposed = false;

  // Transport
  RelayClient? _client;

  // Crypto
  RelayKeyPair? _localKey;
  String? _localFingerprint;
  SecureChannel? _channel;
  Uint8List? _expectedPeerMac;

  // Frame queue: all frames received during handshake are queued
  // and processed sequentially after key derivation completes.
  final _frameQueue = Queue<PeerFrame>();
  bool _processingHandshake = false;

  // Output streams
  final _outputController = StreamController<Uint8List>.broadcast();
  Stream<Uint8List> get output => _outputController.stream;

  final _eventController = StreamController<SecureMessage>.broadcast();
  Stream<SecureMessage> get events => _eventController.stream;

  RelaySession({required this.pairing});

  // ---------------------------------------------------------------------------
  // State transitions
  // ---------------------------------------------------------------------------

  void _setState(SessionState s) {
    if (_disposed) return;
    debugPrint('[session] $_state -> $s');
    _state = s;
    notifyListeners();
  }

  void _setError(String msg) {
    debugPrint('[session] error: $msg');
    _error = msg;
    _setState(SessionState.error);
  }

  // ---------------------------------------------------------------------------
  // Connect
  // ---------------------------------------------------------------------------

  Future<void> connect() async {
    if (_disposed) return;
    _error = null;
    _setState(SessionState.connecting);

    try {
      // Generate ephemeral key pair
      _localKey = await generateKeyPair();
      _localFingerprint = await fingerprint(_localKey!.public_);
      debugPrint('[session] fingerprint: $_localFingerprint');

      // Create relay client
      _client?.dispose();
      _client = RelayClient(relayUrl: pairing.relayUrl);
      _client!.onMessage = _onRelayMessage;
      _client!.onConnected = _onRelayConnected;
      _client!.onDisconnected = _onRelayDisconnected;

      // Listen for relay client state changes (reconnecting, failed, etc)
      _client!.addListener(_onRelayStateChanged);

      // Connect and register
      await _client!.connect(RegisterRequest(
        protocolVersion: protocolVersion,
        protocolVersionMin: protocolVersionMin,
        clientVersion: '0.1.0',
        sessionId: pairing.sessionId,
        pairingCode: pairing.pairingCode,
        role: PeerRole.client,
      ));
    } catch (e) {
      _setError(e.toString());
    }
  }

  // ---------------------------------------------------------------------------
  // Relay client callbacks
  // ---------------------------------------------------------------------------

  void _onRelayConnected() {
    if (_disposed) return;
    debugPrint('[session] relay connected, peer_online=${_client?.registered?.peerOnline}');

    // Reset handshake state on every new connection
    _channel = null;
    _expectedPeerMac = null;
    _frameQueue.clear();
    _processingHandshake = false;

    if (_client?.registered?.peerOnline == true) {
      _sendHandshake();
      _setState(SessionState.handshaking);
    } else {
      _setState(SessionState.waitingForPeer);
    }
  }

  void _onRelayDisconnected() {
    if (_disposed) return;
    // Channel is no longer valid after WebSocket drops
    _channel = null;
    _expectedPeerMac = null;
    _frameQueue.clear();
    _processingHandshake = false;
  }

  void _onRelayStateChanged() {
    if (_disposed) return;
    final clientState = _client?.state;
    if (clientState == ConnectionState.reconnecting) {
      _setState(SessionState.reconnecting);
    } else if (clientState == ConnectionState.failed) {
      _setError(_client?.lastError ?? 'Connection failed');
    }
  }

  // ---------------------------------------------------------------------------
  // Relay message handling
  // ---------------------------------------------------------------------------

  void _onRelayMessage(RelayMessage msg) {
    if (_disposed) return;

    switch (msg) {
      case RelayRouteMsg(route: final route):
        if (route.sessionId != pairing.sessionId) return;
        _onRoute(route);

      case RelayPeerStatus(status: final status):
        _onPeerStatus(status);

      case RelayErrorMsg(error: final err):
        _setError(err.message);

      case RelayPing() || RelayPong() || RelayRegistered() || RelayRegister():
        break;
    }
  }

  void _onPeerStatus(PeerStatus status) {
    debugPrint('[session] peer status: ${status.role} online=${status.online}');
    if (status.role != PeerRole.host) return;

    if (status.online) {
      if (_state == SessionState.waitingForPeer ||
          _state == SessionState.handshaking ||
          _state == SessionState.awaitingConfirm) {
        _sendHandshake();
        _setState(SessionState.handshaking);
      }
    } else {
      if (_state == SessionState.connected) {
        _setError('Host disconnected');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Peer frame handling (Route payloads)
  // ---------------------------------------------------------------------------

  void _onRoute(RelayRoute route) {
    final PeerFrame frame;
    try {
      frame = decodePeerFrame(route.payload);
    } catch (e) {
      debugPrint('[session] bad peer frame: $e');
      return;
    }

    // If handshake is in progress (async key derivation), queue the frame.
    if (_processingHandshake) {
      debugPrint('[session] queuing ${frame.runtimeType} (handshake in progress)');
      _frameQueue.add(frame);
      return;
    }

    _processFrame(frame);
  }

  void _processFrame(PeerFrame frame) {
    switch (frame) {
      case PeerFrameHandshake(handshake: final h):
        _onPeerHandshake(h);

      case PeerFrameHandshakeConfirm(confirm: final c):
        _onPeerConfirm(c);

      case PeerFrameSecure(frame: final sealed):
        _onSecureFrame(sealed);

      case PeerFrameKeepAlive():
        break;
    }
  }

  // ---------------------------------------------------------------------------
  // Handshake
  // ---------------------------------------------------------------------------

  void _sendHandshake() {
    debugPrint('[session] sending handshake');
    _client?.sendPeerFrame(
      pairing.sessionId,
      PeerFrameHandshake(Handshake(
        publicKey: _localKey!.public_,
        fingerprint: _localFingerprint!,
        toolName: 'terminal-relay-app',
        timestampMs: DateTime.now().millisecondsSinceEpoch,
      )),
    );
  }

  Future<void> _onPeerHandshake(Handshake handshake) async {
    debugPrint('[session] peer handshake: fp=${handshake.fingerprint} '
        'tool=${handshake.toolName} key_len=${handshake.publicKey.length}');

    // Validate timestamp
    final now = DateTime.now().millisecondsSinceEpoch;
    final age = now - handshake.timestampMs;
    if (age.abs() > handshakeMaxAgeMs) {
      debugPrint('[session] rejecting stale handshake (age=${age}ms)');
      return;
    }

    // Validate fingerprint
    if (pairing.expectedFingerprint != null &&
        handshake.fingerprint != pairing.expectedFingerprint) {
      _setError('Fingerprint mismatch: expected ${pairing.expectedFingerprint}, '
          'got ${handshake.fingerprint}');
      return;
    }

    _toolName = handshake.toolName;
    _processingHandshake = true;
    _setState(SessionState.handshaking);

    try {
      // Derive session keys (async — this is where the race condition was)
      debugPrint('[session] deriving keys...');
      final keys = await deriveSessionKeys(
        role: PeerRole.client,
        sessionId: pairing.sessionId,
        localSecret: _localKey!.secret,
        remotePublic: handshake.publicKey,
      );
      debugPrint('[session] keys derived');

      // Compute MACs
      final ourMac = await computeHandshakeMac(
        txKey: keys.tx,
        localPublic: _localKey!.public_,
        remotePublic: handshake.publicKey,
        sessionId: pairing.sessionId,
      );
      _expectedPeerMac = await computeHandshakeMac(
        txKey: keys.rx,
        localPublic: handshake.publicKey,
        remotePublic: _localKey!.public_,
        sessionId: pairing.sessionId,
      );

      _channel = SecureChannel(keys);

      // Send our confirmation
      debugPrint('[session] sending confirm');
      _client?.sendPeerFrame(
        pairing.sessionId,
        PeerFrameHandshakeConfirm(HandshakeConfirm(mac: ourMac)),
      );

      _setState(SessionState.awaitingConfirm);
    } catch (e) {
      _setError('Handshake failed: $e');
    } finally {
      _processingHandshake = false;
    }

    // Drain queued frames
    while (_frameQueue.isNotEmpty) {
      final queued = _frameQueue.removeFirst();
      debugPrint('[session] processing queued ${queued.runtimeType}');
      _processFrame(queued);
    }
  }

  void _onPeerConfirm(HandshakeConfirm confirm) {
    debugPrint('[session] peer confirm received');

    if (_expectedPeerMac == null || _channel == null) {
      debugPrint('[session] ignoring confirm: no pending handshake');
      return;
    }

    // Constant-time compare
    if (confirm.mac.length != 32 || _expectedPeerMac!.length != 32) {
      _setError('Invalid MAC length');
      return;
    }
    var diff = 0;
    for (var i = 0; i < 32; i++) {
      diff |= confirm.mac[i] ^ _expectedPeerMac![i];
    }
    if (diff != 0) {
      _setError('Handshake MAC mismatch — possible MITM');
      _channel = null;
      _expectedPeerMac = null;
      return;
    }

    _expectedPeerMac = null;
    _setState(SessionState.connected);
    debugPrint('[session] E2E channel established');
  }

  // ---------------------------------------------------------------------------
  // Secure (encrypted) frames
  // ---------------------------------------------------------------------------

  Future<void> _onSecureFrame(SealedFrame sealed) async {
    if (_state != SessionState.connected || _channel == null) return;

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
      debugPrint('[session] decrypt error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Outbound (user actions)
  // ---------------------------------------------------------------------------

  Future<void> sendInput(Uint8List data) async {
    if (_state != SessionState.connected || _channel == null) return;
    try {
      final sealed = await _channel!.seal(PtyInput(data));
      _client?.sendPeerFrame(pairing.sessionId, PeerFrameSecure(sealed));
    } catch (e) {
      debugPrint('[session] seal error: $e');
    }
  }

  Future<void> sendResize(int cols, int rows) async {
    if (_state != SessionState.connected || _channel == null) return;
    try {
      final sealed = await _channel!.seal(Resize(cols: cols, rows: rows));
      _client?.sendPeerFrame(pairing.sessionId, PeerFrameSecure(sealed));
    } catch (e) {
      debugPrint('[session] seal error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Disconnect
  // ---------------------------------------------------------------------------

  Future<void> disconnect() async {
    // Send goodbye if we have an active channel
    if (_state == SessionState.connected && _channel != null && _client != null) {
      try {
        final sealed = await _channel!.seal(SessionEnded(0));
        _client!.sendPeerFrame(pairing.sessionId, PeerFrameSecure(sealed));
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (_) {}
    }

    _channel = null;
    _expectedPeerMac = null;
    _frameQueue.clear();
    _processingHandshake = false;
    await _client?.disconnect();
    if (!_disposed) _setState(SessionState.disconnected);
  }

  @override
  void dispose() {
    _disposed = true;
    _channel = null;
    _expectedPeerMac = null;
    _frameQueue.clear();
    _client?.dispose();
    _outputController.close();
    _eventController.close();
    super.dispose();
  }
}
