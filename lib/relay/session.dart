import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/crypto.dart';
import '../core/log.dart';
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

  /// Whether the connected host tool supports structured agent events.
  bool get isStructuredTool => _toolName == 'claude' || _toolName == 'opencode';

  /// Local client fingerprint (available after key generation).
  String? get localFingerprint => _localFingerprint;

  /// When the E2E encrypted session was established.
  DateTime? _connectedAt;
  DateTime? get connectedAt => _connectedAt;

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

  // Handshake timeout
  Timer? _handshakeTimer;
  static const _handshakeTimeout = Duration(seconds: 15);

  // Cached app version (avoids repeated platform channel calls)
  static String? _cachedClientVersion;

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
    log('[session] $_state -> $s');
    _state = s;

    // Manage handshake timeout
    if (s == SessionState.handshaking ||
        s == SessionState.awaitingConfirm ||
        s == SessionState.waitingForPeer) {
      _startHandshakeTimer();
    } else {
      _handshakeTimer?.cancel();
      _handshakeTimer = null;
    }

    notifyListeners();
  }

  void _setError(String msg) {
    log('[session] error: $msg');
    _error = msg;
    _handshakeTimer?.cancel();
    _handshakeTimer = null;
    _setState(SessionState.error);
  }

  void _startHandshakeTimer() {
    _handshakeTimer?.cancel();
    _handshakeTimer = Timer(_handshakeTimeout, () {
      if (_disposed) return;
      if (_state == SessionState.handshaking ||
          _state == SessionState.awaitingConfirm ||
          _state == SessionState.waitingForPeer) {
        log('[session] handshake timed out, retrying');
        _retryHandshake();
      }
    });
  }

  void _retryHandshake() {
    _channel = null;
    _expectedPeerMac = null;
    _frameQueue.clear();
    _processingHandshake = false;

    if (_client?.state == RelayConnectionState.connected) {
      // Still connected to relay, just resend handshake
      _sendHandshake();
      _setState(SessionState.handshaking);
    } else {
      // Connection lost, trigger full reconnect
      _client?.reconnectNow();
    }
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
      log('[session] fingerprint: $_localFingerprint');

      // Create relay client
      _client?.dispose();
      _client = RelayClient(relayUrl: pairing.relayUrl, apiKey: pairing.apiKey);
      _client!.onMessage = _onRelayMessage;
      _client!.onConnected = _onRelayConnected;
      _client!.onDisconnected = _onRelayDisconnected;

      // Listen for relay client state changes (reconnecting, failed, etc)
      _client!.addListener(_onRelayStateChanged);

      // Get app version at runtime (cached after first call)
      _cachedClientVersion ??= (await PackageInfo.fromPlatform()).version;

      // Connect and register
      await _client!.connect(
        RegisterRequest(
          protocolVersion: protocolVersion,
          protocolVersionMin: protocolVersionMin,
          clientVersion: _cachedClientVersion!,
          sessionId: pairing.sessionId,
          pairingCode: pairing.pairingCode,
          role: PeerRole.client,
        ),
      );
    } catch (e) {
      _setError(e.toString());
    }
  }

  // ---------------------------------------------------------------------------
  // Relay client callbacks
  // ---------------------------------------------------------------------------

  void _onRelayConnected() {
    if (_disposed) return;
    log(
      '[session] relay connected, peer_online=${_client?.registered?.peerOnline}',
    );

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
    if (clientState == RelayConnectionState.reconnecting) {
      _setState(SessionState.reconnecting);
    } else if (clientState == RelayConnectionState.failed) {
      _setError(
        _client?.lastError ??
            'Could not connect to the relay server. Check your internet connection and try again.',
      );
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

      case RelayPing() ||
          RelayPong() ||
          RelayRegistered() ||
          RelayRegister() ||
          RelayUnknown():
        break;
    }
  }

  void _onPeerStatus(PeerStatus status) {
    log('[session] peer status: ${status.role} online=${status.online}');
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
      log('[session] bad peer frame: $e');
      return;
    }

    // If handshake is in progress (async key derivation), queue the frame.
    if (_processingHandshake) {
      log('[session] queuing ${frame.runtimeType} (handshake in progress)');
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
      case PeerFrameUnknown():
        break;
    }
  }

  // ---------------------------------------------------------------------------
  // Handshake
  // ---------------------------------------------------------------------------

  void _sendHandshake() {
    log('[session] sending handshake');
    _client?.sendPeerFrame(
      pairing.sessionId,
      PeerFrameHandshake(
        Handshake(
          publicKey: _localKey!.public_,
          fingerprint: _localFingerprint!,
          toolName: 'farwatch-app',
          timestampMs: DateTime.now().millisecondsSinceEpoch,
        ),
      ),
    );
  }

  Future<void> _onPeerHandshake(Handshake handshake) async {
    log(
      '[session] peer handshake: fp=${handshake.fingerprint} '
      'tool=${handshake.toolName} key_len=${handshake.publicKey.length}',
    );

    // Ignore duplicate handshakes if we already have a channel (in-progress
    // or confirmed) or if we're currently processing one. This handles the
    // dual-handshake race where both sides send Handshake simultaneously —
    // the first one processed wins, and the second is safely dropped.
    if (_channel != null || _processingHandshake) {
      log(
        '[session] ignoring duplicate handshake '
        '(channel=${_channel != null}, processing=$_processingHandshake, '
        'state=$_state)',
      );
      return;
    }

    // Validate timestamp
    final now = DateTime.now().millisecondsSinceEpoch;
    final age = now - handshake.timestampMs;
    if (age.abs() > handshakeMaxAgeMs) {
      log('[session] rejecting stale handshake (age=${age}ms)');
      return;
    }

    // Validate fingerprint
    if (pairing.expectedFingerprint != null &&
        handshake.fingerprint != pairing.expectedFingerprint) {
      _setError(
        'Host identity changed. The host fingerprint doesn\'t match the one '
        'in your pairing code. This could mean the host restarted or someone '
        'is intercepting the connection. Try scanning a new QR code.',
      );
      return;
    }

    _toolName = handshake.toolName;
    _processingHandshake = true;
    _setState(SessionState.handshaking);

    try {
      // Derive session keys (async — this is where the race condition was)
      log('[session] deriving keys...');
      final keys = await deriveSessionKeys(
        role: PeerRole.client,
        sessionId: pairing.sessionId,
        localSecret: _localKey!.secret,
        remotePublic: handshake.publicKey,
      );
      log('[session] keys derived');

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
      log('[session] sending confirm');
      _client?.sendPeerFrame(
        pairing.sessionId,
        PeerFrameHandshakeConfirm(HandshakeConfirm(mac: ourMac)),
      );

      _setState(SessionState.awaitingConfirm);
    } catch (e) {
      _setError('Secure connection setup failed. Please try reconnecting.');
    } finally {
      _processingHandshake = false;
    }

    // Drain queued frames
    while (_frameQueue.isNotEmpty) {
      final queued = _frameQueue.removeFirst();
      log('[session] processing queued ${queued.runtimeType}');
      _processFrame(queued);
    }
  }

  void _onPeerConfirm(HandshakeConfirm confirm) {
    log('[session] peer confirm received');

    if (_expectedPeerMac == null || _channel == null) {
      log('[session] ignoring confirm: no pending handshake');
      return;
    }

    // Constant-time compare (uses crypto.dart helper)
    if (!constantTimeMacEqual(confirm.mac, _expectedPeerMac!)) {
      _setError(
        'Security verification failed. The encrypted handshake could not be '
        'verified, which may indicate a man-in-the-middle attack. '
        'Disconnecting for safety. Try reconnecting with a new QR code.',
      );
      _channel = null;
      _expectedPeerMac = null;
      return;
    }

    _expectedPeerMac = null;
    _connectedAt = DateTime.now();
    _setState(SessionState.connected);
    log('[session] E2E channel established');
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

        // Structured agent events → event stream for native UI rendering.
        case AgentEvent():
          _eventController.add(msg);

        case PtyInput() ||
            Resize() ||
            Heartbeat() ||
            VoiceCommand() ||
            AgentCommand() ||
            UnknownMessage():
          break;
      }
    } catch (e) {
      log('[session] decrypt error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Outbound (user actions)
  // ---------------------------------------------------------------------------

  /// Encrypt and send a [SecureMessage] to the peer. No-op if not connected.
  Future<void> _sendSecure(SecureMessage msg) async {
    if (_state != SessionState.connected || _channel == null) return;
    try {
      final sealed = await _channel!.seal(msg);
      _client?.sendPeerFrame(pairing.sessionId, PeerFrameSecure(sealed));
    } catch (e) {
      log('[session] seal error: $e');
    }
  }

  Future<void> sendInput(Uint8List data) => _sendSecure(PtyInput(data));

  Future<void> sendResize(int cols, int rows) =>
      _sendSecure(Resize(cols: cols, rows: rows));

  Future<void> sendVoiceCommand({
    required String transcript,
    String? intent,
    required double confidence,
  }) => _sendSecure(
    VoiceCommand(
      transcript: transcript,
      intent: intent,
      confidence: confidence,
    ),
  );

  Future<void> sendAgentPrompt(String text) =>
      _sendSecure(AgentPrompt(text: text));

  Future<void> sendApproveToolUse(String id) =>
      _sendSecure(AgentApproveToolUse(id: id));

  Future<void> sendDenyToolUse(String id, {String? reason}) =>
      _sendSecure(AgentDenyToolUse(id: id, reason: reason));

  // ---------------------------------------------------------------------------
  // App lifecycle
  // ---------------------------------------------------------------------------

  void pauseHeartbeat() {
    _client?.pauseHeartbeat();
  }

  void resumeOrReconnect() {
    if (_disposed || _client == null) return;

    final clientState = _client!.state;
    if (clientState == RelayConnectionState.connected) {
      // Connection still alive, just resume heartbeat
      _client!.resumeHeartbeat();
    } else if (clientState != RelayConnectionState.connecting) {
      // Connection died while backgrounded, reconnect immediately
      log('[session] connection lost while backgrounded, reconnecting');
      _client!.reconnectNow();
    }
  }

  // ---------------------------------------------------------------------------
  // Disconnect
  // ---------------------------------------------------------------------------

  Future<void> disconnect() async {
    // Send goodbye if we have an active channel
    if (_state == SessionState.connected &&
        _channel != null &&
        _client != null) {
      try {
        final sealed = await _channel!.seal(SessionEnded(0));
        _client!.sendPeerFrame(pairing.sessionId, PeerFrameSecure(sealed));
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (_) {}
    }

    _handshakeTimer?.cancel();
    _handshakeTimer = null;
    _channel?.dispose();
    _channel = null;
    _expectedPeerMac = null;
    _frameQueue.clear();
    _processingHandshake = false;
    // Zero out ephemeral key material
    zeroOut(_localKey?.secret);
    zeroOut(_localKey?.public_);
    _localKey = null;
    await _client?.disconnect();
    if (!_disposed) _setState(SessionState.disconnected);
  }

  @override
  void dispose() {
    _disposed = true;
    _handshakeTimer?.cancel();
    _channel?.dispose();
    _channel = null;
    _expectedPeerMac = null;
    _frameQueue.clear();
    // Zero out ephemeral key material
    zeroOut(_localKey?.secret);
    zeroOut(_localKey?.public_);
    _localKey = null;
    _client?.dispose();
    _outputController.close();
    _eventController.close();
    super.dispose();
  }
}
