import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/pairing.dart';
import '../../core/session_history.dart';
import '../../providers/session_history_provider.dart';
import '../../theme/farwatch_colors.dart';
import '../adaptive.dart';
import '../widgets/home/empty_state.dart';
import '../widgets/home/manual_entry_sheet.dart';
import '../widgets/home/session_tile.dart';
import 'scan_screen.dart';
import 'terminal_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSessions = ref.watch(sessionHistoryProvider);
    final sessions = asyncSessions.valueOrNull ?? [];
    final loading = asyncSessions.isLoading && !asyncSessions.hasValue;

    if (isApplePlatform) {
      return _buildCupertinoScreen(context, ref, sessions, loading);
    }
    return _buildMaterialScreen(context, ref, sessions, loading);
  }

  // ---------------------------------------------------------------------------
  // Navigation helpers
  // ---------------------------------------------------------------------------

  void _openScanner(BuildContext context, WidgetRef ref) async {
    final result = await Navigator.of(context).push<PairingUri>(
      adaptivePageRoute(builder: (_) => const ScanScreen()),
    );
    if (result != null && context.mounted) {
      _navigateToTerminal(context, ref, result);
    }
  }

  void _navigateToTerminal(
      BuildContext context, WidgetRef ref, PairingUri pairing) {
    Navigator.of(context)
        .push(adaptivePageRoute(
            builder: (_) => TerminalScreen(pairing: pairing)))
        .then((_) => ref.invalidate(sessionHistoryProvider));
  }

  void _reconnectSession(
      BuildContext context, WidgetRef ref, SessionRecord record) {
    try {
      final pairing = PairingUri.parse(record.pairingUri);
      _navigateToTerminal(context, ref, pairing);
    } catch (e) {
      showAdaptiveToast(context, 'Invalid session data: $e');
    }
  }

  void _connectFromUri(BuildContext context, WidgetRef ref, String uri) {
    try {
      final pairing = PairingUri.parse(uri);
      _navigateToTerminal(context, ref, pairing);
    } catch (e) {
      showAdaptiveToast(context, 'Invalid pairing URI: $e');
    }
  }

  void _clearHistory(BuildContext context, WidgetRef ref) async {
    final confirmed = await showAdaptiveConfirmDialog(
      context: context,
      title: 'Clear history?',
      content: 'This will remove all saved session records.',
      confirmLabel: 'Clear',
      isDestructive: true,
    );
    if (confirmed) {
      ref.read(sessionHistoryProvider.notifier).clear();
    }
  }

  // ---------------------------------------------------------------------------
  // Session list
  // ---------------------------------------------------------------------------

  Widget _buildSessionList(
      BuildContext context, WidgetRef ref, List<SessionRecord> sessions) {
    final c = context.colors;
    if (isApplePlatform) {
      return CustomScrollView(
        slivers: [
          SliverSafeArea(
            top: false,
            sliver: SliverPadding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => SessionTile(
                    record: sessions[i],
                    onTap: () =>
                        _reconnectSession(context, ref, sessions[i]),
                    onDelete: () => ref
                        .read(sessionHistoryProvider.notifier)
                        .remove(sessions[i].sessionId),
                  ),
                  childCount: sessions.length,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text('Recent Sessions',
              style: TextStyle(
                  color: c.textTertiary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5)),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: sessions.length,
            separatorBuilder: (_, _) =>
                Divider(height: 1, color: c.surfacePrimary),
            itemBuilder: (_, i) => SessionTile(
              record: sessions[i],
              onTap: () => _reconnectSession(context, ref, sessions[i]),
              onDelete: () => ref
                  .read(sessionHistoryProvider.notifier)
                  .remove(sessions[i].sessionId),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Shells
  // ---------------------------------------------------------------------------

  Widget _buildMaterialScreen(BuildContext context, WidgetRef ref,
      List<SessionRecord> sessions, bool loading) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        title: const Text('Farwatch'),
        backgroundColor: Colors.transparent,
        foregroundColor: c.textPrimary,
        actions: [
          if (sessions.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Clear history',
              onPressed: () => _clearHistory(context, ref),
            ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : sessions.isEmpty
              ? EmptyState(
                  onScanQr: () => _openScanner(context, ref),
                  onPasteUri: () => showManualEntry(context,
                      onConnect: (uri) =>
                          _connectFromUri(context, ref, uri)),
                )
              : _buildSessionList(context, ref, sessions),
      floatingActionButton: sessions.isNotEmpty
          ? FloatingActionButton(
              onPressed: () => _openScanner(context, ref),
              tooltip: 'Scan QR Code',
              child: const Icon(Icons.qr_code_scanner),
            )
          : null,
    );
  }

  Widget _buildCupertinoScreen(BuildContext context, WidgetRef ref,
      List<SessionRecord> sessions, bool loading) {
    final c = context.colors;
    return CupertinoPageScaffold(
      backgroundColor: c.background,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: c.navBarBackground,
        middle: Text('Farwatch', style: TextStyle(color: c.textPrimary)),
        leading: sessions.isNotEmpty
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                onPressed: () => _clearHistory(context, ref),
                child: Icon(CupertinoIcons.trash,
                    size: 20, color: c.statusNeutral),
              )
            : null,
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: () => _openScanner(context, ref),
          child: Icon(CupertinoIcons.qrcode_viewfinder,
              size: 22, color: c.accent),
        ),
      ),
      child: SafeArea(
        top: false,
        child: loading
            ? const Center(child: CupertinoActivityIndicator())
            : sessions.isEmpty
                ? EmptyState(
                    onScanQr: () => _openScanner(context, ref),
                    onPasteUri: () => showManualEntry(context,
                        onConnect: (uri) =>
                            _connectFromUri(context, ref, uri)),
                  )
                : _buildSessionList(context, ref, sessions),
      ),
    );
  }
}
