import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';

import '../core/log.dart';

/// Immutable snapshot of speech-to-text state.
@immutable
class SpeechState {
  final bool available;
  final bool listening;
  final String liveTranscript;

  /// Set when a transcript is finalized (user stopped or speech engine
  /// returned "done"). The consuming widget reads this once to fill
  /// the prompt bar, then it is cleared.
  final String? completedTranscript;

  const SpeechState({
    this.available = false,
    this.listening = false,
    this.liveTranscript = '',
    this.completedTranscript,
  });

  SpeechState copyWith({
    bool? available,
    bool? listening,
    String? liveTranscript,
    String? completedTranscript,
    bool clearCompleted = false,
  }) {
    return SpeechState(
      available: available ?? this.available,
      listening: listening ?? this.listening,
      liveTranscript: liveTranscript ?? this.liveTranscript,
      completedTranscript: clearCompleted
          ? null
          : (completedTranscript ?? this.completedTranscript),
    );
  }
}

/// Provider for speech-to-text. AutoDispose cleans up when terminal screen pops.
final speechProvider =
    NotifierProvider.autoDispose<SpeechNotifier, SpeechState>(
      SpeechNotifier.new,
    );

class SpeechNotifier extends AutoDisposeNotifier<SpeechState> {
  late final stt.SpeechToText _speech;

  @override
  SpeechState build() {
    _speech = stt.SpeechToText();
    ref.onDispose(() {
      if (state.listening) _speech.stop();
    });
    // Kick off async init.
    _initialize();
    return const SpeechState();
  }

  Future<void> _initialize() async {
    final available = await _speech.initialize(
      onError: (error) {
        log('[stt] error: ${error.errorMsg}');
        state = state.copyWith(listening: false);
      },
      onStatus: (status) {
        log('[stt] status: $status');
        if (status == 'done') {
          _onDone();
        }
      },
    );
    state = state.copyWith(available: available);
  }

  void startListening() {
    if (!state.available || state.listening) return;
    state = state.copyWith(
      listening: true,
      liveTranscript: '',
      clearCompleted: true,
    );
    _speech.listen(
      onResult: _onResult,
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.dictation,
        cancelOnError: false,
        partialResults: true,
      ),
    );
  }

  void stopListening() {
    if (!state.listening) return;
    _speech.stop();
    state = state.copyWith(listening: false);
    _finalize();
  }

  /// Clear the completed transcript after the consumer has read it.
  void clearCompletedTranscript() {
    state = state.copyWith(clearCompleted: true);
  }

  void _onResult(SpeechRecognitionResult result) {
    state = state.copyWith(liveTranscript: result.recognizedWords);
  }

  void _onDone() {
    state = state.copyWith(listening: false);
    _finalize();
  }

  void _finalize() {
    final transcript = state.liveTranscript.trim();
    if (transcript.isEmpty) return;
    state = state.copyWith(completedTranscript: transcript, liveTranscript: '');
  }
}
