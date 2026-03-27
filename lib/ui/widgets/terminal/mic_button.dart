import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/speech_provider.dart';
import '../../../theme/farwatch_colors.dart';
import '../../adaptive.dart';

/// Floating mic button for starting/stopping speech-to-text.
class MicButton extends ConsumerWidget {
  const MicButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speech = ref.watch(speechProvider);
    final c = context.colors;

    void toggle() {
      if (speech.listening) {
        ref.read(speechProvider.notifier).stopListening();
      } else {
        HapticFeedback.heavyImpact();
        ref.read(speechProvider.notifier).startListening();
      }
    }

    if (isApplePlatform) {
      return CupertinoButton(
        padding: const EdgeInsets.all(14),
        color: speech.listening ? c.micActive : c.micIdle,
        borderRadius: BorderRadius.circular(28),
        onPressed: toggle,
        child: Icon(
          speech.listening ? CupertinoIcons.mic_fill : CupertinoIcons.mic,
          color: speech.listening ? c.textPrimary : c.textSecondary,
          size: 22,
        ),
      );
    }

    return FloatingActionButton(
      backgroundColor: speech.listening ? c.micActive : c.micIdle,
      onPressed: toggle,
      tooltip: speech.listening ? 'Tap to stop' : 'Tap to speak',
      child: Icon(
        speech.listening ? Icons.mic : Icons.mic_none,
        color: speech.listening ? c.textPrimary : c.textSecondary,
        size: 24,
      ),
    );
  }
}
