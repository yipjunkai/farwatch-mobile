import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/protocol.dart';

/// Configuration for reconnect behavior.
class ReconnectConfig {
  final int maxAttempts;
  final Duration initialDelay;
  final Duration maxDelay;

  const ReconnectConfig({
    this.maxAttempts = 10,
    this.initialDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
  });

  Duration delayForAttempt(int attempt) {
    final ms = initialDelay.inMilliseconds * pow(2, attempt).toInt();
    return Duration(milliseconds: min(ms, maxDelay.inMilliseconds));
  }
}

/// Connection state visible to consumers.
enum ConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  failed,
}

/// Thin WebSocket wrapper that handles:
/// - Connection lifecycle and registration
/// - Automatic reconnect with exponential backoff
/// - Heartbeat pings
/// - Message decoding
///
/// Messages are delivered via a callback set by the session layer.
/// Registration is handled internally -- the session never sees Register/Registered.
class RelayClient extends ChangeNotifier {
  final String _relayUrl;
  final ReconnectConfig _reconnectConfig;

  WebSocketChannel? _channel;
  StreamSubscription? _channelSub;
  Timer? _heartbeatTimer;
  RegisterRequest? _lastRequest;

  ConnectionState _state = ConnectionState.disconnected;
  ConnectionState get state => _state;

  RegisterResponse? _registered;
  RegisterResponse? get registered => _registered;

  String? _lastError;
  String? get lastError => _lastError;

  int _reconnectAttempt = 0;
  bool _disposed = false;
  bool _intentionalClose = false;

  /// Message callback set by the session layer.
  void Function(RelayMessage msg)? onMessage;

  /// Called when connection state changes to connected (including reconnect).
  void Function()? onConnected;

  /// Called when connection is lost (before reconnect attempt).
  void Function()? onDisconnected;

  RelayClient({
    required String relayUrl,
    ReconnectConfig reconnectConfig = const ReconnectConfig(),
  })  : _relayUrl = relayUrl,
        _reconnectConfig = reconnectConfig;

  void _setState(ConnectionState s) {
    if (_disposed) return;
    debugPrint('[relay] state: $s');
    _state = s;
    notifyListeners();
  }

  /// Connect to the relay and register.
  Future<void> connect(RegisterRequest request) async {
    if (_disposed) return;
    _lastRequest = request;
    _intentionalClose = false;
    _reconnectAttempt = 0;
    await _connectOnce(request);
  }

  Future<void> _connectOnce(RegisterRequest request) async {
    if (_disposed || _intentionalClose) return;
    _setState(ConnectionState.connecting);
    _lastError = null;

    try {
      await _teardownChannel();

      final wsUrl = Uri.parse(_relayUrl);
      _channel = WebSocketChannel.connect(wsUrl);
      await _channel!.ready.timeout(const Duration(seconds: 15));

      // Registration phase: collect messages until we get Registered.
      final registeredCompleter = Completer<RegisterResponse>();
      final buffered = <RelayMessage>[];

      _channelSub = _channel!.stream.listen(
        (data) {
          if (data is! List<int>) return;
          try {
            final msg = decodeRelay(Uint8List.fromList(data));

            if (!registeredCompleter.isCompleted) {
              // During registration phase
              if (msg is RelayRegistered) {
                registeredCompleter.complete(msg.response);
              } else if (msg is RelayErrorMsg) {
                registeredCompleter.completeError(
                  Exception('Registration failed: ${msg.error.message}'),
                );
              } else {
                // Buffer messages that arrive before registration completes
                buffered.add(msg);
              }
            } else {
              // Post-registration: deliver to session
              onMessage?.call(msg);
            }
          } catch (e) {
            debugPrint('[relay] decode error: $e');
          }
        },
        onError: (e) {
          debugPrint('[relay] ws error: $e');
          if (!registeredCompleter.isCompleted) {
            registeredCompleter.completeError(e);
          } else {
            _handleDisconnect();
          }
        },
        onDone: () {
          debugPrint('[relay] ws closed');
          if (!registeredCompleter.isCompleted) {
            registeredCompleter.completeError(
              Exception('WebSocket closed during registration'),
            );
          } else {
            _handleDisconnect();
          }
        },
      );

      // Send Register
      _rawSend(encodeRelay(RelayRegister(request)));

      // Wait for Registered
      _registered = await registeredCompleter.future
          .timeout(const Duration(seconds: 15));

      _reconnectAttempt = 0;
      _setState(ConnectionState.connected);

      // Start heartbeat
      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(
        const Duration(seconds: 10),
        (_) => send(RelayPing(DateTime.now().millisecondsSinceEpoch)),
      );

      debugPrint('[relay] connected, peer_online=${_registered!.peerOnline}');

      // Deliver buffered messages
      for (final msg in buffered) {
        onMessage?.call(msg);
      }

      // Notify session
      onConnected?.call();
    } catch (e) {
      debugPrint('[relay] connect failed: $e');
      _lastError = e.toString();
      _handleDisconnect();
    }
  }

  void _handleDisconnect() {
    if (_disposed || _intentionalClose) return;

    _heartbeatTimer?.cancel();
    onDisconnected?.call();

    if (_reconnectAttempt >= _reconnectConfig.maxAttempts) {
      _lastError ??= 'Failed after ${_reconnectConfig.maxAttempts} attempts';
      _setState(ConnectionState.failed);
      return;
    }

    _setState(ConnectionState.reconnecting);
    final delay = _reconnectConfig.delayForAttempt(_reconnectAttempt);
    _reconnectAttempt++;
    debugPrint('[relay] reconnecting in ${delay.inMilliseconds}ms '
        '(attempt $_reconnectAttempt/${_reconnectConfig.maxAttempts})');

    Future.delayed(delay, () {
      if (!_disposed && !_intentionalClose && _lastRequest != null) {
        _connectOnce(_lastRequest!);
      }
    });
  }

  /// Send an encoded RelayMessage.
  void send(RelayMessage msg) {
    _rawSend(encodeRelay(msg));
  }

  /// Send a PeerFrame wrapped in a Route.
  void sendPeerFrame(String sessionId, PeerFrame frame) {
    final payload = encodePeerFrame(frame);
    send(RelayRouteMsg(RelayRoute(sessionId: sessionId, payload: payload)));
  }

  void _rawSend(Uint8List bytes) {
    if (_channel == null) return;
    try {
      _channel!.sink.add(bytes);
    } catch (e) {
      debugPrint('[relay] send error: $e');
    }
  }

  Future<void> _teardownChannel() async {
    _heartbeatTimer?.cancel();
    _channelSub?.cancel();
    _channelSub = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  /// Force an immediate reconnect (e.g. after app resume).
  /// Skips backoff delay. No-op if already connected or disposed.
  void reconnectNow() {
    if (_disposed || _intentionalClose) return;
    if (_state == ConnectionState.connected) return;
    if (_lastRequest == null) return;
    debugPrint('[relay] reconnectNow requested');
    _reconnectAttempt = 0;
    _connectOnce(_lastRequest!);
  }

  /// Pause heartbeats (e.g. when app is backgrounded).
  void pauseHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Resume heartbeats (e.g. when app is foregrounded).
  void resumeHeartbeat() {
    if (_state != ConnectionState.connected) return;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => send(RelayPing(DateTime.now().millisecondsSinceEpoch)),
    );
  }

  /// Gracefully disconnect. No reconnect.
  Future<void> disconnect() async {
    _intentionalClose = true;
    await _teardownChannel();
    if (!_disposed) _setState(ConnectionState.disconnected);
  }

  @override
  void dispose() {
    _disposed = true;
    _intentionalClose = true;
    _heartbeatTimer?.cancel();
    _channelSub?.cancel();
    try {
      _channel?.sink.close();
    } catch (_) {}
    super.dispose();
  }
}
