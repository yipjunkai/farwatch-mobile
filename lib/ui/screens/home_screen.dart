import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

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
    HapticFeedback.selectionClick();
    final result = await Navigator.of(
      context,
    ).push<PairingUri>(adaptivePageRoute(builder: (_) => const ScanScreen()));
    if (result != null && context.mounted) {
      _navigateToTerminal(context, ref, result);
    }
  }

  void _navigateToTerminal(
    BuildContext context,
    WidgetRef ref,
    PairingUri pairing,
  ) {
    Navigator.of(context)
        .push(
          adaptivePageRoute(builder: (_) => TerminalScreen(pairing: pairing)),
        )
        .then((_) => ref.invalidate(sessionHistoryProvider));
  }

  void _reconnectSession(
    BuildContext context,
    WidgetRef ref,
    SessionRecord record,
  ) {
    HapticFeedback.selectionClick();
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
      HapticFeedback.mediumImpact();
      ref.read(sessionHistoryProvider.notifier).clear();
    }
  }

  // ---------------------------------------------------------------------------
  // Session list (sliver-based, used inside CustomScrollView)
  // ---------------------------------------------------------------------------

  List<Widget> _buildSessionSlivers(
    BuildContext context,
    WidgetRef ref,
    List<SessionRecord> sessions,
  ) {
    return [
      SliverSafeArea(
        top: false,
        sliver: SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => SessionTile(
                record: sessions[i],
                onTap: () => _reconnectSession(context, ref, sessions[i]),
                onDelete: () => ref
                    .read(sessionHistoryProvider.notifier)
                    .remove(sessions[i].sessionId),
              ),
              childCount: sessions.length,
            ),
          ),
        ),
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // Legal footer
  // ---------------------------------------------------------------------------

  Widget _buildLegalFooter(FarwatchColors c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () => launchUrl(
              Uri.parse('https://farwatch.dev/privacy-policy'),
              mode: LaunchMode.externalApplication,
            ),
            child: Text(
              'Privacy Policy',
              style: TextStyle(color: c.textTertiary, fontSize: 12),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '·',
              style: TextStyle(color: c.textTertiary, fontSize: 12),
            ),
          ),
          GestureDetector(
            onTap: () => launchUrl(
              Uri.parse('https://farwatch.dev/terms-and-conditions'),
              mode: LaunchMode.externalApplication,
            ),
            child: Text(
              'Terms',
              style: TextStyle(color: c.textTertiary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Material shell
  // ---------------------------------------------------------------------------

  Widget _buildMaterialScreen(
    BuildContext context,
    WidgetRef ref,
    List<SessionRecord> sessions,
    bool loading,
  ) {
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
          ? Column(
              children: [
                Expanded(
                  child: EmptyState(
                    onScanQr: () => _openScanner(context, ref),
                    onPasteUri: () => showManualEntry(
                      context,
                      onConnect: (uri) => _connectFromUri(context, ref, uri),
                    ),
                  ),
                ),
                _buildLegalFooter(c),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text(
                    'Recent Sessions',
                    style: TextStyle(
                      color: c.textTertiary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    physics: adaptiveScrollPhysics,
                    itemCount: sessions.length + 1,
                    separatorBuilder: (context, i) =>
                        i < sessions.length - 1
                            ? Divider(height: 1, color: c.surfacePrimary)
                            : const SizedBox.shrink(),
                    itemBuilder: (_, i) {
                      if (i == sessions.length) {
                        return _buildLegalFooter(c);
                      }
                      return SessionTile(
                        record: sessions[i],
                        onTap: () => _reconnectSession(context, ref, sessions[i]),
                        onDelete: () => ref
                            .read(sessionHistoryProvider.notifier)
                            .remove(sessions[i].sessionId),
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: sessions.isNotEmpty
          ? FloatingActionButton(
              onPressed: () => _openScanner(context, ref),
              tooltip: 'Scan QR Code',
              child: const Icon(Icons.qr_code_scanner),
            )
          : null,
    );
  }

  // ---------------------------------------------------------------------------
  // Cupertino shell — large title, single QR button in nav bar
  // ---------------------------------------------------------------------------

  Widget _buildCupertinoScreen(
    BuildContext context,
    WidgetRef ref,
    List<SessionRecord> sessions,
    bool loading,
  ) {
    final c = context.colors;
    return CupertinoPageScaffold(
      backgroundColor: c.background,
      child: CustomScrollView(
        physics: adaptiveScrollPhysics,
        slivers: [
          CupertinoSliverNavigationBar(
            backgroundColor: c.navBarBackground,
            largeTitle: Text(
              'Farwatch',
              style: TextStyle(color: c.textPrimary),
            ),
            leading: sessions.isNotEmpty
                ? CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    onPressed: () => _clearHistory(context, ref),
                    child: Text(
                      'Clear',
                      style: TextStyle(color: c.statusError, fontSize: 17),
                    ),
                  )
                : null,
            trailing: sessions.isNotEmpty
                ? CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    onPressed: () => _openScanner(context, ref),
                    child: Icon(
                      CupertinoIcons.qrcode_viewfinder,
                      size: 24,
                      color: c.accent,
                    ),
                  )
                : null,
          ),
          if (loading)
            const SliverFillRemaining(
              child: Center(child: CupertinoActivityIndicator()),
            )
          else if (sessions.isEmpty)
            SliverFillRemaining(
              child: EmptyState(
                onScanQr: () => _openScanner(context, ref),
                onPasteUri: () => showManualEntry(
                  context,
                  onConnect: (uri) => _connectFromUri(context, ref, uri),
                ),
              ),
            )
          else
            ..._buildSessionSlivers(context, ref, sessions),
          SliverToBoxAdapter(child: _buildLegalFooter(c)),
        ],
      ),
    );
  }
}
