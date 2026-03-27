import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/speech_provider.dart';
import '../../../theme/farwatch_colors.dart';
import '../../adaptive.dart';
import 'pulsing_dot.dart';

/// Overlay that appears during active speech recognition.
class ListeningOverlay extends ConsumerWidget {
  const ListeningOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speech = ref.watch(speechProvider);
    final c = context.colors;
    return Positioned(
      bottom: 80 + MediaQuery.of(context).padding.bottom,
      left: 24,
      right: 24,
      child: GlassContainer(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const PulsingDot(),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                speech.liveTranscript.isEmpty
                    ? 'Listening...'
                    : speech.liveTranscript,
                style: TextStyle(
                  color: speech.liveTranscript.isEmpty
                      ? c.textSecondary
                      : c.textPrimary,
                  fontSize: 14,
                  fontStyle: speech.liveTranscript.isEmpty
                      ? FontStyle.italic
                      : FontStyle.normal,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
