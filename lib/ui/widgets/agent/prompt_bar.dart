import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/pairing.dart';
import '../../../providers/agent_state_provider.dart';
import '../../../providers/speech_provider.dart';
import '../../../providers/terminal_session_provider.dart';
import '../../../theme/farwatch_colors.dart';
import '../../adaptive.dart';

/// Text input bar with send/mic button for structured agent mode.
class PromptBar extends ConsumerStatefulWidget {
  final PairingUri pairing;
  const PromptBar({super.key, required this.pairing});

  @override
  ConsumerState<PromptBar> createState() => _PromptBarState();
}

class _PromptBarState extends ConsumerState<PromptBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    // Echo the user's prompt as a chat bubble before sending.
    ref.read(agentStateProvider.notifier).addUserPrompt(text);
    ref
        .read(terminalSessionProvider(widget.pairing).notifier)
        .sendAgentPrompt(text);
    _controller.clear();
  }

  void _onAction(bool hasText, SpeechState speech) {
    if (hasText) {
      _send();
    } else if (speech.listening) {
      ref.read(speechProvider.notifier).stopListening();
    } else if (speech.available) {
      HapticFeedback.heavyImpact();
      ref.read(speechProvider.notifier).startListening();
    }
  }

  @override
  Widget build(BuildContext context) {
    final agent = ref.watch(agentStateProvider);
    final speech = ref.watch(speechProvider);
    final c = context.colors;

    if (speech.completedTranscript != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _controller.text = speech.completedTranscript!;
        _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: _controller.text.length),
        );
        ref.read(speechProvider.notifier).clearCompletedTranscript();
        HapticFeedback.mediumImpact();
      });
    }

    final hasText = _controller.text.trim().isNotEmpty;
    if (isApplePlatform) return _buildCupertino(c, hasText, agent, speech);
    return _buildMaterial(c, hasText, agent, speech);
  }

  Widget _buildCupertino(
    FarwatchColors c,
    bool hasText,
    AgentState agent,
    SpeechState speech,
  ) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: c.glassSurface,
            border: Border(top: BorderSide(color: c.glassBorder)),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: CupertinoTextField(
                    controller: _controller,
                    enabled: !agent.agentBusy,
                    style: TextStyle(color: c.textPrimary, fontSize: 14),
                    placeholder: speech.listening
                        ? 'Listening...'
                        : agent.agentBusy
                        ? 'Agent is working...'
                        : 'Send a prompt...',
                    placeholderStyle: TextStyle(
                      color: speech.listening ? c.micActive : c.textPlaceholder,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: c.inputBackground,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 36,
                  height: 36,
                  child: agent.agentBusy
                      ? const Center(child: CupertinoActivityIndicator())
                      : CupertinoButton(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          color: hasText
                              ? c.accent
                              : (speech.listening ? c.micActive : c.micIdle),
                          borderRadius: BorderRadius.circular(18),
                          onPressed: () => _onAction(hasText, speech),
                          child: Icon(
                            hasText
                                ? CupertinoIcons.arrow_up
                                : speech.listening
                                ? CupertinoIcons.stop_fill
                                : CupertinoIcons.mic,
                            color: c.textPrimary,
                            size: 18,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMaterial(
    FarwatchColors c,
    bool hasText,
    AgentState agent,
    SpeechState speech,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c.surfacePrimary,
        border: Border(top: BorderSide(color: c.promptBarBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: !agent.agentBusy,
                style: TextStyle(color: c.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: speech.listening
                      ? 'Listening...'
                      : agent.agentBusy
                      ? 'Agent is working...'
                      : 'Send a prompt...',
                  hintStyle: TextStyle(
                    color: speech.listening ? c.micActive : c.textPlaceholder,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: c.surfaceTertiary),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: c.surfaceTertiary),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: c.surfaceSecondary),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  isDense: true,
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 40,
              height: 40,
              child: agent.agentBusy
                  ? Container(
                      decoration: BoxDecoration(
                        color: c.surfaceSecondary,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: c.sendActive,
                          ),
                        ),
                      ),
                    )
                  : Material(
                      color: hasText
                          ? c.sendActive
                          : (speech.listening ? c.micActive : c.micIdle),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => _onAction(hasText, speech),
                        child: Center(
                          child: Icon(
                            hasText
                                ? Icons.arrow_upward
                                : speech.listening
                                ? Icons.stop
                                : Icons.mic,
                            color: c.textPrimary,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
