import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../core/pairing.dart';
import '../../core/session_history.dart';
import '../adaptive.dart';
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
      adaptivePageRoute(builder: (_) => const ScanScreen()),
    );
    if (result != null && mounted) {
      _navigateToTerminal(result);
    }
  }

  void _navigateToTerminal(PairingUri pairing) {
    Navigator.of(context)
        .push(
      adaptivePageRoute(builder: (_) => TerminalScreen(pairing: pairing)),
    )
        .then((_) {
      _loadSessions();
    });
  }

  void _reconnectSession(SessionRecord record) {
    try {
      final pairing = PairingUri.parse(record.pairingUri);
      _navigateToTerminal(pairing);
    } catch (e) {
      showAdaptiveToast(context, 'Invalid session data: $e');
    }
  }

  void _showManualEntry() {
    if (isApplePlatform) {
      _showCupertinoManualEntry();
    } else {
      _showMaterialManualEntry();
    }
  }

  void _showCupertinoManualEntry() {
    final controller = TextEditingController();
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Paste pairing URI'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            placeholder: 'farwatch://pair?...',
            autofocus: true,
            maxLines: 3,
            style: const TextStyle(fontSize: 13),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              final text = controller.text.trim();
              Navigator.pop(ctx);
              controller.dispose();
              if (text.isNotEmpty) {
                _connectFromUri(text);
              }
            },
            child: const Text('Connect'),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }

  void _showMaterialManualEntry() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ManualEntrySheet(
        onConnect: (uri) => _connectFromUri(uri),
      ),
    );
  }

  void _connectFromUri(String uri) {
    try {
      final pairing = PairingUri.parse(uri);
      _navigateToTerminal(pairing);
    } catch (e) {
      showAdaptiveToast(context, 'Invalid pairing URI: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Delete / clear
  // ---------------------------------------------------------------------------

  void _deleteSession(SessionRecord record) async {
    await SessionHistory.remove(record.sessionId);
    _loadSessions();
  }

  void _clearHistory() async {
    final confirmed = await showAdaptiveConfirmDialog(
      context: context,
      title: 'Clear history?',
      content: 'This will remove all saved session records.',
      confirmLabel: 'Clear',
      isDestructive: true,
    );
    if (confirmed) {
      await SessionHistory.clear();
      _loadSessions();
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

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

  Widget _buildEmptyState() {
    if (isApplePlatform) return _buildCupertinoEmptyState();
    return _buildMaterialEmptyState();
  }

  Widget _buildMaterialEmptyState() {
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

  Widget _buildCupertinoEmptyState() {
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
            CupertinoButton.filled(
              onPressed: _openScanner,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.qrcode_viewfinder, size: 20),
                  SizedBox(width: 8),
                  Text('Scan QR Code'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            CupertinoButton(
              onPressed: _showManualEntry,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.link, size: 18),
                  SizedBox(width: 8),
                  Text('Paste URI'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Session list
  // ---------------------------------------------------------------------------

  Widget _buildSessionList() {
    if (isApplePlatform) return _buildCupertinoSessionList();
    return _buildMaterialSessionList();
  }

  Widget _buildMaterialSessionList() {
    return Column(
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
            itemBuilder: (_, i) => _buildMaterialTile(_sessions[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildMaterialTile(SessionRecord record) {
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

  Widget _buildCupertinoSessionList() {
    return CustomScrollView(
      slivers: [
        SliverSafeArea(
          top: false,
          sliver: SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildCupertinoTile(_sessions[index]),
                childCount: _sessions.length,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCupertinoTile(SessionRecord record) {
    final endIcon = switch (record.endReason) {
      SessionEndReason.unknown => CupertinoIcons.circle,
      SessionEndReason.userDisconnected => CupertinoIcons.square_arrow_right,
      SessionEndReason.hostEnded => CupertinoIcons.stop_circle,
      SessionEndReason.connectionLost => CupertinoIcons.wifi_slash,
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
        decoration: BoxDecoration(
          color: CupertinoColors.destructiveRed,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(CupertinoIcons.delete, color: CupertinoColors.white),
      ),
      onDismissed: (_) => _deleteSession(record),
      child: GlassContainer(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: () => _reconnectSession(record),
          child: Row(
            children: [
              Icon(toolIcon, color: CupertinoColors.systemTeal, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.displayName,
                      style: const TextStyle(
                        color: CupertinoColors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ago,
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(endIcon, size: 14, color: endColor),
              const SizedBox(width: 4),
              const Icon(
                CupertinoIcons.chevron_right,
                size: 16,
                color: CupertinoColors.systemGrey,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build — platform branching at top level
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (isApplePlatform) return _buildCupertinoScreen();
    return _buildMaterialScreen();
  }

  Widget _buildMaterialScreen() {
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
              : _buildSessionList(),
      floatingActionButton: _sessions.isNotEmpty
          ? FloatingActionButton(
              onPressed: _openScanner,
              tooltip: 'Scan QR Code',
              child: const Icon(Icons.qr_code_scanner),
            )
          : null,
    );
  }

  Widget _buildCupertinoScreen() {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: const Color(0xB01C1C1E),
        middle: const Text(
          'Farwatch',
          style: TextStyle(color: CupertinoColors.white),
        ),
        leading: _sessions.isNotEmpty
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                onPressed: _clearHistory,
                child: const Icon(
                  CupertinoIcons.trash,
                  size: 20,
                  color: CupertinoColors.systemGrey,
                ),
              )
            : null,
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: _openScanner,
          child: const Icon(
            CupertinoIcons.qrcode_viewfinder,
            size: 22,
            color: CupertinoColors.systemTeal,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CupertinoActivityIndicator())
            : _sessions.isEmpty
                ? _buildEmptyState()
                : _buildSessionList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Manual URI entry bottom sheet (Material only — iOS uses CupertinoAlertDialog)
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
