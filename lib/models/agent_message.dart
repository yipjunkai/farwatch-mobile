/// Type of agent message for rendering different card styles.
enum AgentMessageType {
  system,
  text,
  thinking,
  toolCall,
  toolResult,
  toolError,
  turnMarker,
  permissionRequest,
}

/// A single message in the structured agent view.
///
/// Mutable `text` field allows streaming deltas to append in place
/// (text and thinking messages grow incrementally).
class AgentMessage {
  final int id;
  final AgentMessageType type;
  String text;
  final String? toolId;
  final String? toolInput;
  final String? toolName;

  AgentMessage({
    required this.id,
    required this.type,
    required this.text,
    this.toolId,
    this.toolInput,
    this.toolName,
  });
}
