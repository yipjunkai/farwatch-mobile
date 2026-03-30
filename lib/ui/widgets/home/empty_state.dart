import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../theme/farwatch_colors.dart';
import '../../adaptive.dart';

/// "No sessions yet" placeholder with scan and paste URI buttons.
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
    if (isApplePlatform) return _buildIOS(c);
    return _buildMaterial(c);
  }

  Widget _buildIOS(FarwatchColors c) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: c.surfaceSecondary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                CupertinoIcons.desktopcomputer,
                size: 34,
                color: c.textTertiary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No sessions yet',
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Run farwatch start on your computer,\nthen scan the QR code to connect.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            _GradientButton(
              onPressed: onScanQr,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.qrcode_viewfinder,
                      size: 20, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Scan QR Code',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      )),
                ],
              ),
            ),
            const SizedBox(height: 12),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 10),
              onPressed: onPasteUri,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.link, size: 16, color: c.accent),
                  const SizedBox(width: 6),
                  Text('Paste URI',
                      style: TextStyle(color: c.accent, fontSize: 15)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterial(FarwatchColors c) {
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
        ),
      ),
    );
  }
}

/// Coral-to-purple gradient button matching the app's warm accent.
class _GradientButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget child;

  const _GradientButton({required this.onPressed, required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              colors: [
                Color(0xFFE07A6A), // warm coral
                Color(0xFFD4736A), // rose
                Color(0xFF9B6B9E), // mauve
                Color(0xFF7B5EA7), // purple
              ],
            ),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}
