import 'package:flutter/material.dart';

import '../../../core/pairing.dart';
import '../../../models/agent_message.dart';
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
    return switch (message.type) {
      AgentMessageType.system => _SystemCard(text: message.text),
      AgentMessageType.text => _TextCard(text: message.text),
      AgentMessageType.thinking => _ThinkingCard(text: message.text),
      AgentMessageType.toolCall => _ToolCallCard(
          name: message.text, input: message.toolInput),
      AgentMessageType.toolResult => _ResultCard(text: message.text),
      AgentMessageType.toolError => _ErrorCard(text: message.text),
      AgentMessageType.turnMarker => _TurnMarker(text: message.text),
      AgentMessageType.permissionRequest =>
          PermissionCard(message: message, pairing: pairing),
    };
  }
}

// ---------------------------------------------------------------------------
// Individual card widgets (small, focused, no provider dependencies)
// ---------------------------------------------------------------------------

class _SystemCard extends StatelessWidget {
  final String text;
  const _SystemCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.blueGrey.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text,
            style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
                fontFamily: 'monospace')),
      ),
    );
  }
}

class _TextCard extends StatelessWidget {
  final String text;
  const _TextCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SelectableText(text,
          style: const TextStyle(
              color: Colors.white, fontSize: 14, height: 1.5)),
    );
  }
}

class _ThinkingCard extends StatelessWidget {
  final String text;
  const _ThinkingCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.purple.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.psychology, color: Colors.purple[300], size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text,
                  style: TextStyle(
                      color: Colors.purple[200],
                      fontSize: 13,
                      fontStyle: FontStyle.italic)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolCallCard extends StatelessWidget {
  final String name;
  final String? input;
  const _ToolCallCard({required this.name, this.input});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.cyan.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.cyan.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.build, color: Colors.cyan[300], size: 16),
              const SizedBox(width: 6),
              Text(name,
                  style: TextStyle(
                      color: Colors.cyan[200],
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ]),
            if (input != null && input!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                input!.length > 200
                    ? '${input!.substring(0, 200)}...'
                    : input!,
                style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 11,
                    fontFamily: 'monospace'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final String text;
  const _ResultCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          text.length > 300 ? '${text.substring(0, 300)}...' : text,
          style: TextStyle(
              color: Colors.grey[500], fontSize: 11, fontFamily: 'monospace'),
          maxLines: 10,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String text;
  const _ErrorCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                style:
                    const TextStyle(color: Colors.redAccent, fontSize: 12),
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
  const _TurnMarker({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Expanded(child: Divider(color: Colors.grey[700])),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(text,
              style: TextStyle(color: Colors.grey[600], fontSize: 11)),
        ),
        Expanded(child: Divider(color: Colors.grey[700])),
      ]),
    );
  }
}
