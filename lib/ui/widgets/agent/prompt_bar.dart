import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/pairing.dart';
import '../../../providers/agent_state_provider.dart';
import '../../../providers/speech_provider.dart';
import '../../../providers/terminal_session_provider.dart';
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
    ref
        .read(terminalSessionProvider(widget.pairing).notifier)
        .sendAgentPrompt(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final agent = ref.watch(agentStateProvider);
    final speech = ref.watch(speechProvider);

    // Fill prompt bar with completed transcript from speech provider.
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

    if (isApplePlatform) {
      return _buildCupertino(hasText, agent, speech);
    }
    return _buildMaterial(hasText, agent, speech);
  }

  Widget _buildCupertino(bool hasText, AgentState agent, SpeechState speech) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xCC1C1C1E),
            border: Border(
                top: BorderSide(
                    color: Colors.white.withValues(alpha: 0.1))),
          ),
          child: SafeArea(
            top: false,
            child: Row(children: [
              Expanded(
                child: CupertinoTextField(
                  controller: _controller,
                  enabled: !agent.agentBusy,
                  style: const TextStyle(
                      color: CupertinoColors.white, fontSize: 14),
                  placeholder: speech.listening
                      ? 'Listening...'
                      : agent.agentBusy
                          ? 'Agent is working...'
                          : 'Send a prompt...',
                  placeholderStyle: TextStyle(
                      color: speech.listening
                          ? CupertinoColors.destructiveRed
                          : Colors.grey[600]),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                      color: const Color(0xFF2C2C2E),
                      borderRadius: BorderRadius.circular(20)),
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
                            ? CupertinoColors.systemTeal
                            : (speech.listening
                                ? CupertinoColors.destructiveRed
                                : const Color(0xFF3A3A3C)),
                        borderRadius: BorderRadius.circular(18),
                        onPressed: () => _onAction(hasText, speech),
                        child: Icon(
                          hasText
                              ? CupertinoIcons.arrow_up
                              : speech.listening
                                  ? CupertinoIcons.stop_fill
                                  : CupertinoIcons.mic,
                          color: CupertinoColors.white,
                          size: 18,
                        ),
                      ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildMaterial(bool hasText, AgentState agent, SpeechState speech) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: Border(top: BorderSide(color: Colors.grey[800]!)),
      ),
      child: SafeArea(
        top: false,
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: !agent.agentBusy,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: speech.listening
                    ? 'Listening...'
                    : agent.agentBusy
                        ? 'Agent is working...'
                        : 'Send a prompt...',
                hintStyle: TextStyle(
                    color: speech.listening
                        ? Colors.redAccent
                        : Colors.grey[600]),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: Colors.grey[700]!)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: Colors.grey[700]!)),
                disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: Colors.grey[800]!)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
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
                        color: Colors.grey[800], shape: BoxShape.circle),
                    child: Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.cyan[300]),
                      ),
                    ),
                  )
                : Material(
                    color: hasText
                        ? Colors.cyan
                        : (speech.listening
                            ? Colors.redAccent
                            : Colors.grey[800]!),
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
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
          ),
        ]),
      ),
    );
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
}
