import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../core/pairing.dart';
import '../../core/session_history.dart';
import 'scan_screen.dart';
import 'terminal_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  List<SessionRecord> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final sessions = await SessionHistory.load();
    if (mounted) {
      setState(() {
        _sessions = sessions;
        _loading = false;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  void _openScanner() async {
    final result = await Navigator.of(context).push<PairingUri>(
      MaterialPageRoute(builder: (_) => const ScanScreen()),
    );
    if (result != null && mounted) {
      _navigateToTerminal(result);
    }
  }

  void _navigateToTerminal(PairingUri pairing) {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => TerminalScreen(pairing: pairing),
      ),
    )
        .then((_) {
      // Reload history when returning from terminal screen
      _loadSessions();
    });
  }

  void _reconnectSession(SessionRecord record) {
    try {
      final pairing = PairingUri.parse(record.pairingUri);
      _navigateToTerminal(pairing);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid session data: $e')),
      );
    }
  }

  void _showManualEntry() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ManualEntrySheet(
        onConnect: (uri) {
          try {
            final pairing = PairingUri.parse(uri);
            _navigateToTerminal(pairing);
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Invalid pairing URI: $e')),
            );
          }
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Delete / clear
  // ---------------------------------------------------------------------------

  void _deleteSession(SessionRecord record) async {
    await SessionHistory.remove(record.sessionId);
    _loadSessions();
  }

  void _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear history?'),
        content: const Text('This will remove all saved session records.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await SessionHistory.clear();
      _loadSessions();
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.terminal, size: 64, color: Colors.grey[700]),
            const SizedBox(height: 24),
            Text(
              'No sessions yet',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Run farwatch start on your computer,\nthen scan the QR code to connect.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _openScanner,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan QR Code'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _showManualEntry,
              icon: const Icon(Icons.link),
              label: const Text('Paste URI'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionTile(SessionRecord record) {
    final endIcon = switch (record.endReason) {
      SessionEndReason.unknown => Icons.circle,
      SessionEndReason.userDisconnected => Icons.logout,
      SessionEndReason.hostEnded => Icons.stop_circle_outlined,
      SessionEndReason.connectionLost => Icons.wifi_off,
    };

    final endColor = switch (record.endReason) {
      SessionEndReason.unknown => Colors.grey,
      SessionEndReason.userDisconnected => Colors.grey,
      SessionEndReason.hostEnded => Colors.orange,
      SessionEndReason.connectionLost => Colors.red,
    };

    final toolIcon = _toolIcon(record.toolName);
    final ago = timeago.format(record.lastActiveAt);

    return Dismissible(
      key: Key(record.sessionId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: Colors.red[900],
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _deleteSession(record),
      child: ListTile(
        leading: Icon(toolIcon, color: Colors.teal, size: 28),
        title: Text(
          record.displayName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          ago,
          style: TextStyle(color: Colors.grey[500], fontSize: 12),
        ),
        trailing: Icon(endIcon, size: 14, color: endColor),
        onTap: () => _reconnectSession(record),
      ),
    );
  }

  IconData _toolIcon(String? toolName) {
    if (toolName == null) return Icons.terminal;
    final name = toolName.toLowerCase();
    if (name.contains('claude')) return Icons.auto_awesome;
    if (name.contains('copilot')) return Icons.smart_toy;
    if (name.contains('gemini')) return Icons.diamond;
    if (name.contains('aider')) return Icons.code;
    if (name.contains('goose')) return Icons.flight;
    if (name.contains('opencode')) return Icons.developer_board;
    return Icons.terminal;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Farwatch'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        actions: [
          if (_sessions.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Clear history',
              onPressed: _clearHistory,
            ),

        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
              ? _buildEmptyState()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Text(
                        'Recent Sessions',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        itemCount: _sessions.length,
                        separatorBuilder: (_, _) => Divider(
                          height: 1,
                          color: Colors.grey[900],
                        ),
                        itemBuilder: (_, i) => _buildSessionTile(_sessions[i]),
                      ),
                    ),
                  ],
                ),
      floatingActionButton: _sessions.isNotEmpty
          ? FloatingActionButton(
              onPressed: _openScanner,
              tooltip: 'Scan QR Code',
              child: const Icon(Icons.qr_code_scanner),
            )
          : null,
    );
  }
}

// ---------------------------------------------------------------------------
// Manual URI entry bottom sheet (owns its own TextEditingController)
// ---------------------------------------------------------------------------

class _ManualEntrySheet extends StatefulWidget {
  final void Function(String uri) onConnect;

  const _ManualEntrySheet({required this.onConnect});

  @override
  State<_ManualEntrySheet> createState() => _ManualEntrySheetState();
}

class _ManualEntrySheetState extends State<_ManualEntrySheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Paste pairing URI',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              hintText: 'farwatch://pair?...',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              final text = _controller.text.trim();
              Navigator.pop(context);
              if (text.isNotEmpty) {
                widget.onConnect(text);
              }
            },
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }
}
