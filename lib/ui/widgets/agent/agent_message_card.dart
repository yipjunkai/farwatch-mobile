import 'package:flutter/material.dart';

import '../../../core/pairing.dart';
import '../../../models/agent_message.dart';
import '../../../theme/farwatch_colors.dart';
import 'permission_card.dart';

/// Renders a single [AgentMessage] as the appropriate card type.
class AgentMessageCard extends StatelessWidget {
  final AgentMessage message;
  final PairingUri pairing;

  const AgentMessageCard({
    super.key,
    required this.message,
    required this.pairing,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return switch (message.type) {
      AgentMessageType.system => _SystemCard(text: message.text, colors: c),
      AgentMessageType.text => _TextCard(text: message.text, colors: c),
      AgentMessageType.thinking => _ThinkingCard(text: message.text, colors: c),
      AgentMessageType.toolCall => _ToolCallCard(name: message.text, input: message.toolInput, colors: c),
      AgentMessageType.toolResult => _ResultCard(text: message.text, colors: c),
      AgentMessageType.toolError => _ErrorCard(text: message.text, colors: c),
      AgentMessageType.turnMarker => _TurnMarker(text: message.text, colors: c),
      AgentMessageType.permissionRequest => PermissionCard(message: message, pairing: pairing),
    };
  }
}

class _SystemCard extends StatelessWidget {
  final String text;
  final FarwatchColors colors;
  const _SystemCard({required this.text, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colors.systemSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text,
            style: TextStyle(color: colors.textSecondary, fontSize: 12, fontFamily: 'monospace')),
      ),
    );
  }
}

class _TextCard extends StatelessWidget {
  final String text;
  final FarwatchColors colors;
  const _TextCard({required this.text, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SelectableText(text,
          style: TextStyle(color: colors.textPrimary, fontSize: 14, height: 1.5)),
    );
  }
}

class _ThinkingCard extends StatelessWidget {
  final String text;
  final FarwatchColors colors;
  const _ThinkingCard({required this.text, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colors.thinkingSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.thinkingBorder),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.psychology, color: colors.thinkingIcon, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(color: colors.thinkingAccent, fontSize: 13, fontStyle: FontStyle.italic)),
          ),
        ]),
      ),
    );
  }
}

class _ToolCallCard extends StatelessWidget {
  final String name;
  final String? input;
  final FarwatchColors colors;
  const _ToolCallCard({required this.name, this.input, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colors.toolCallSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.toolCallBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.build, color: colors.toolCallAccent, size: 16),
            const SizedBox(width: 6),
            Text(name,
                style: TextStyle(color: colors.toolCallAccent, fontWeight: FontWeight.bold, fontSize: 13)),
          ]),
          if (input != null && input!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              input!.length > 200 ? '${input!.substring(0, 200)}...' : input!,
              style: TextStyle(color: colors.textTertiary, fontSize: 11, fontFamily: 'monospace'),
            ),
          ],
        ]),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final String text;
  final FarwatchColors colors;
  const _ResultCard({required this.text, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colors.resultSurface,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          text.length > 300 ? '${text.substring(0, 300)}...' : text,
          style: TextStyle(color: colors.textTertiary, fontSize: 11, fontFamily: 'monospace'),
          maxLines: 10,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String text;
  final FarwatchColors colors;
  const _ErrorCard({required this.text, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colors.errorSurface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: colors.errorBorder),
        ),
        child: Row(children: [
          Icon(Icons.error_outline, color: colors.statusErrorAccent, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                style: TextStyle(color: colors.statusErrorAccent, fontSize: 12),
                maxLines: 5,
                overflow: TextOverflow.ellipsis),
          ),
        ]),
      ),
    );
  }
}

class _TurnMarker extends StatelessWidget {
  final String text;
  final FarwatchColors colors;
  const _TurnMarker({required this.text, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Expanded(child: Divider(color: colors.surfaceTertiary)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(text, style: TextStyle(color: colors.textPlaceholder, fontSize: 11)),
        ),
        Expanded(child: Divider(color: colors.surfaceTertiary)),
      ]),
    );
  }
}
