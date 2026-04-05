import 'dart:convert';

/// Safely parses tool input JSON and extracts common fields.
///
/// Returns null for malformed JSON. Each getter returns null if the key
/// is missing rather than throwing.
class ToolInputParser {
  final Map<String, dynamic>? _json;

  ToolInputParser(String? rawInput) : _json = _tryParse(rawInput);

  static Map<String, dynamic>? _tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (_) {
      return null;
    }
  }

  bool get isValid => _json != null;

  /// File path (used by mcp_read, mcp_write, mcp_edit, mcp_glob).
  String? get filePath => _json?['filePath'] as String?;

  /// Command string (used by mcp_bash).
  String? get command => _json?['command'] as String?;

  /// Description (used by mcp_bash).
  String? get description => _json?['description'] as String?;

  /// URL (used by mcp_webfetch).
  String? get url => _json?['url'] as String?;

  /// Format (used by mcp_webfetch).
  String? get format => _json?['format'] as String?;

  /// Pattern (used by mcp_glob, mcp_grep).
  String? get pattern => _json?['pattern'] as String?;

  /// Include pattern (used by mcp_grep).
  String? get include => _json?['include'] as String?;

  /// Path (used by mcp_grep, mcp_glob).
  String? get path => _json?['path'] as String?;

  /// Old string (used by mcp_edit).
  String? get oldString => _json?['oldString'] as String?;

  /// New string (used by mcp_edit).
  String? get newString => _json?['newString'] as String?;

  /// Content to write (used by mcp_write).
  String? get content => _json?['content'] as String?;

  /// Working directory (used by mcp_bash).
  String? get workdir => _json?['workdir'] as String?;

  /// Offset (used by mcp_read).
  int? get offset => _json?['offset'] as int?;

  /// Limit (used by mcp_read).
  int? get limit => _json?['limit'] as int?;

  /// Replace all flag (used by mcp_edit).
  bool? get replaceAll => _json?['replaceAll'] as bool?;

  /// Raw JSON map access for anything else.
  Map<String, dynamic>? get raw => _json;
}
