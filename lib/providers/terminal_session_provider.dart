import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';

import '../core/pairing.dart';
import '../core/protocol.dart';
import '../core/session_history.dart';
import '../relay/session.dart';
import 'agent_state_provider.dart';
import 'session_history_provider.dart';

/// Immutable snapshot of the terminal session state, exposed to widgets.
@immutable
class TerminalSessionState {
  final SessionState sessionState;
  final String? error;
  final String? toolName;
  final bool isStructuredTool;

  const TerminalSessionState({
    this.sessionState = SessionState.disconnected,
    this.error,
    this.toolName,
    this.isStructuredTool = false,
  });

  TerminalSessionState copyWith({
    SessionState? sessionState,
    String? error,
    String? toolName,
    bool? isStructuredTool,
    bool clearError = false,
  }) {
    return TerminalSessionState(
      sessionState: sessionState ?? this.sessionState,
      error: clearError ? null : (error ?? this.error),
      toolName: toolName ?? this.toolName,
      isStructuredTool: isStructuredTool ?? this.isStructuredTool,
    );
  }
}

/// Provider for the terminal session, parameterized by [PairingUri].
///
/// Each terminal screen gets its own instance. AutoDispose ensures the
/// [RelaySession] and [Terminal] are cleaned up when the screen pops.
final terminalSessionProvider = NotifierProvider.autoDispose
    .family<TerminalSessionNotifier, TerminalSessionState, PairingUri>(
      TerminalSessionNotifier.new,
    );

class TerminalSessionNotifier
    extends AutoDisposeFamilyNotifier<TerminalSessionState, PairingUri> {
  late final RelaySession _session;
  late final Terminal _terminal;
  StreamSubscription? _outputSub;
  StreamSubscription? _eventSub;

  /// The xterm [Terminal] instance for the [TerminalView] widget.
  Terminal get terminal => _terminal;

  /// The underlying [RelaySession] (for direct access if needed).
  RelaySession get session => _session;

  @override
  TerminalSessionState build(PairingUri pairing) {
    _terminal = Terminal(
      maxLines: 10000,
      onOutput: (data) {
        _session.sendInput(Uint8List.fromList(data.codeUnits));
      },
      onResize: (width, height, pixelWidth, pixelHeight) {
        _session.sendResize(width, height);
      },
    );

    _session = RelaySession(pairing: pairing);
    _session.addListener(_onSessionChanged);

    // Pipe PTY output bytes → Terminal widget.
    _outputSub = _session.output.listen((bytes) {
      _terminal.write(utf8.decode(bytes, allowMalformed: true));
    });

    // Pipe structured events → AgentStateProvider.
    _eventSub = _session.events.listen(_onEvent);

    // Clean up on dispose.
    ref.onDispose(() {
      _outputSub?.cancel();
      _eventSub?.cancel();
      _session.removeListener(_onSessionChanged);
      _session.dispose();
    });

    return const TerminalSessionState();
  }

  // ── Session lifecycle ──────────────────────────────────────────────────

  Future<void> connect() async {
    state = state.copyWith(clearError: true);
    await _session.connect();
  }

  Future<void> disconnect() async {
    await _session.disconnect();
    _updateHistory(SessionEndReason.userDisconnected);
  }

  void pauseHeartbeat() => _session.pauseHeartbeat();
  void resumeOrReconnect() => _session.resumeOrReconnect();

  // ── Outbound commands (delegated to RelaySession) ──────────────────────

  void sendInput(Uint8List data) => _session.sendInput(data);
  void sendResize(int cols, int rows) => _session.sendResize(cols, rows);
  void sendAgentPrompt(String text) => _session.sendAgentPrompt(text);
  void sendApproveToolUse(String id) => _session.sendApproveToolUse(id);
  void sendDenyToolUse(String id) => _session.sendDenyToolUse(id);
  void sendVoiceCommand({
    required String transcript,
    String? intent,
    required double confidence,
  }) => _session.sendVoiceCommand(
    transcript: transcript,
    intent: intent,
    confidence: confidence,
  );

  // ── Internal ───────────────────────────────────────────────────────────

  void _onSessionChanged() {
    state = TerminalSessionState(
      sessionState: _session.state,
      error: _session.error,
      toolName: _session.toolName,
      isStructuredTool: _session.isStructuredTool,
    );

    // Auto-enable structured view on connect.
    if (_session.state == SessionState.connected && _session.isStructuredTool) {
      ref.read(agentStateProvider.notifier).enableStructuredView();
    }

    // Persist session history on key transitions.
    if (_session.state == SessionState.connected) {
      _saveSessionRecord();
    } else if (_session.state == SessionState.error) {
      _updateHistory(SessionEndReason.connectionLost);
    }
  }

  void _onEvent(SecureMessage msg) {
    final toast = ref.read(agentStateProvider.notifier).handleEvent(msg);

    // Trigger event-appropriate haptic feedback.
    AgentStateNotifier.triggerHaptic(msg);

    // Handle session-ending events for history persistence.
    if (msg is SessionEnded) {
      _updateHistory(SessionEndReason.hostEnded);
    }

    // The toast string is returned to the widget layer via a callback.
    // We store it transiently so the widget can show it.
    if (toast != null) {
      _pendingToast = toast;
      // Trigger a state rebuild so the widget can read the toast.
      state = state.copyWith();
    }
  }

  /// Pending toast message for the widget to display. Read once and cleared.
  String? _pendingToast;
  String? consumeToast() {
    final t = _pendingToast;
    _pendingToast = null;
    return t;
  }

  void _saveSessionRecord() {
    final record = SessionRecord.fromPairing(
      arg,
    ).copyWith(toolName: _session.toolName, lastActiveAt: DateTime.now());
    ref.read(sessionHistoryProvider.notifier).upsert(record);
  }

  void _updateHistory(SessionEndReason reason) {
    ref
        .read(sessionHistoryProvider.notifier)
        .updateSession(
          arg.sessionId,
          lastActiveAt: DateTime.now(),
          endReason: reason,
        );
  }
}
