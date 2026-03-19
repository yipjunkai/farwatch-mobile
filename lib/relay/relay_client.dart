import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/protocol.dart';

/// WebSocket connection to the terminal-relay server.
class RelayClient {
  final WebSocketChannel _channel;

  /// Messages that arrived before the session listener was attached.
  final Queue<RelayMessage> _pendingMessages = Queue<RelayMessage>();

  /// The session sets this callback to receive messages.
  void Function(RelayMessage)? _onMessage;
  void Function(Object)? _onError;
  void Function()? _onDone;

  RegisterResponse? registered;
  bool _closed = false;

  RelayClient._(this._channel) {
    _channel.stream.listen(
      (data) {
        debugPrint('[ws] received data type: ${data.runtimeType}');
        if (data is! List<int>) return;
        try {
          final msg = decodeRelay(Uint8List.fromList(data));
          debugPrint('[ws] decoded: ${msg.runtimeType}');
          _deliver(msg);
        } catch (e) {
          debugPrint('[ws] decode error: $e');
        }
      },
      onError: (error) {
        if (_onError != null) {
          _onError!(error);
        }
      },
      onDone: () {
        _closed = true;
        if (_onDone != null) {
          _onDone!();
        }
      },
    );
  }

  void _deliver(RelayMessage msg) {
    if (_onMessage != null) {
      _onMessage!(msg);
    } else {
      // Buffer until a listener is attached
      _pendingMessages.add(msg);
    }
  }

  /// Set the message handler. Any buffered messages are delivered immediately.
  void listen({
    required void Function(RelayMessage) onMessage,
    void Function(Object)? onError,
    void Function()? onDone,
  }) {
    _onMessage = onMessage;
    _onError = onError;
    _onDone = onDone;

    // Drain any messages that arrived before the listener was set
    while (_pendingMessages.isNotEmpty) {
      _onMessage!(_pendingMessages.removeFirst());
    }
  }

  /// Connect to the relay and register.
  static Future<RelayClient> connect({
    required String relayUrl,
    required RegisterRequest request,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final wsUrl = Uri.parse(relayUrl);
    final channel = WebSocketChannel.connect(wsUrl);
    await channel.ready.timeout(timeout);

    final client = RelayClient._(channel);

    // Send Register message
    client.sendRaw(encodeRelay(RelayRegister(request)));

    // Wait for Registered response. Messages are buffered in the queue
    // until the session calls listen().
    final completer = Completer<RegisterResponse>();
    client._onMessage = (msg) {
      if (msg is RelayRegistered) {
        // Stop consuming, buffer the rest for the session
        client._onMessage = null;
        completer.complete(msg.response);
      } else if (msg is RelayErrorMsg) {
        client._onMessage = null;
        completer.completeError(
          Exception('Registration failed: ${msg.error.message}'),
        );
      } else {
        // Buffer any other messages (e.g. PeerStatus) for the session
        client._pendingMessages.add(msg);
      }
    };

    client.registered = await completer.future.timeout(timeout);
    return client;
  }

  bool get isClosed => _closed;

  void sendRaw(Uint8List bytes) {
    if (!_closed) {
      _channel.sink.add(bytes);
    }
  }

  void send(RelayMessage msg) {
    sendRaw(encodeRelay(msg));
  }

  void sendPeerFrame(String sessionId, PeerFrame frame) {
    final payload = encodePeerFrame(frame);
    send(RelayRouteMsg(RelayRoute(sessionId: sessionId, payload: payload)));
  }

  void sendHandshake({
    required String sessionId,
    required Uint8List publicKey,
    required String fingerprint,
    String? toolName,
  }) {
    sendPeerFrame(
      sessionId,
      PeerFrameHandshake(Handshake(
        publicKey: publicKey,
        fingerprint: fingerprint,
        toolName: toolName,
        timestampMs: DateTime.now().millisecondsSinceEpoch,
      )),
    );
  }

  Future<void> close() async {
    _closed = true;
    await _channel.sink.close();
  }
}
