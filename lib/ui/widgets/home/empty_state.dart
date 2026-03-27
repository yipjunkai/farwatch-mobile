import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../theme/farwatch_colors.dart';
import '../../adaptive.dart';

/// "No sessions yet" placeholder with scan and paste URI buttons.
/// Renders platform-adaptive buttons internally.
class EmptyState extends StatelessWidget {
  final VoidCallback onScanQr;
  final VoidCallback onPasteUri;

  const EmptyState({
    super.key,
    required this.onScanQr,
    required this.onPasteUri,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.terminal, size: 64, color: c.surfaceTertiary),
            const SizedBox(height: 24),
            Text(
              'No sessions yet',
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Run farwatch start on your computer,\nthen scan the QR code to connect.',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textPlaceholder, fontSize: 14),
            ),
            const SizedBox(height: 32),
            if (isApplePlatform) ...[
              CupertinoButton.filled(
                onPressed: onScanQr,
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
                onPressed: onPasteUri,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.link, size: 18),
                    SizedBox(width: 8),
                    Text('Paste URI'),
                  ],
                ),
              ),
            ] else ...[
              FilledButton.icon(
                onPressed: onScanQr,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan QR Code'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onPasteUri,
                icon: const Icon(Icons.link),
                label: const Text('Paste URI'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
