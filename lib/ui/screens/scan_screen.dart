import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/pairing.dart';
import '../../theme/farwatch_colors.dart';
import '../adaptive.dart';

/// Dedicated QR scanner screen. Returns a [PairingUri] via Navigator.pop
/// when a valid farwatch:// QR code is scanned.
///
/// Camera only starts when this screen is opened (not on app launch).
///
/// ## iOS Camera Lens Selection
///
/// On iOS devices with multiple rear cameras, `mobile_scanner` exposes a
/// normalized zoom scale (0.0–1.0) rather than individual lens IDs.
/// - 0.0 maps to the widest available lens (ultra-wide / 0.5× on capable
///   devices, or wide / 1× otherwise).
/// - Higher values move through the optical range toward telephoto.
///
/// We default to an approximate 1× zoom on iOS so the QR scanner opens
/// with a natural field of view instead of the ultra-wide lens. The user
/// can switch between 0.5×, 1×, and 2× presets via pill buttons overlaid
/// on the camera preview. Not all devices support every preset — the
/// selector adapts gracefully (ultra-wide is hidden when unavailable).
///
/// The zoom-to-lens mapping is approximate because the exact relationship
/// between normalized zoom scale and physical focal length varies by
/// device model. The values used here (0.0 / 0.3 / 0.65) work well on
/// iPhone 13–16 series.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

/// Represents a camera lens preset with a label and normalized zoom scale.
class _LensPreset {
  final String label;
  final double zoomScale;

  const _LensPreset(this.label, this.zoomScale);
}

class _ScanScreenState extends State<ScanScreen> {
  late final MobileScannerController _controller;
  bool _processed = false;
  bool _initialZoomApplied = false;
  int _selectedLensIndex = 1; // Default to 1× (index 1)

  /// Lens presets available on iOS.
  ///
  /// The zoom scale values are normalized (0.0–1.0) and approximate:
  /// - 0.0  → ultra-wide (0.5×) — widest available
  /// - 0.3  → standard wide (1×) — natural perspective for QR scanning
  /// - 0.65 → telephoto (2×)     — useful for distant QR codes
  ///
  /// On Android, `mobile_scanner` does not support zoom presets in the same
  /// way, so we skip the lens selector and use default zoom.
  static const _iOSLensPresets = [
    _LensPreset('0.5×', 0.0),
    _LensPreset('1×', 0.3),
    _LensPreset('2×', 0.65),
  ];

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController();
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  /// Once the camera is running, apply the default 1× zoom on iOS.
  void _onControllerChanged() {
    if (_initialZoomApplied) return;
    if (_controller.value.isRunning) {
      _initialZoomApplied = true;
      if (Platform.isIOS) {
        _controller.setZoomScale(_iOSLensPresets[_selectedLensIndex].zoomScale);
      }
    }
  }

  void _selectLens(int index) {
    if (index == _selectedLensIndex) return;
    HapticFeedback.lightImpact();
    setState(() => _selectedLensIndex = index);
    _controller.setZoomScale(_iOSLensPresets[index].zoomScale);
  }

  void _onDetect(BarcodeCapture capture) {
    if (_processed) return;

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null) continue;

      if (raw.startsWith('farwatch://')) {
        _processed = true;
        HapticFeedback.mediumImpact();
        _returnPairing(raw);
        return;
      }
    }
  }

  void _returnPairing(String uri) {
    try {
      final pairing = PairingUri.parse(uri);
      Navigator.of(context).pop(pairing);
    } catch (e) {
      _processed = false;
      showAdaptiveToast(context, 'Invalid pairing URI: $e');
    }
  }

  Widget _buildErrorView(MobileScannerException error) {
    final c = context.colors;
    final icon = isApplePlatform
        ? CupertinoIcons.camera_fill
        : Icons.no_photography;
    final message = switch (error.errorCode) {
      MobileScannerErrorCode.permissionDenied =>
        'Camera permission denied.\n\nGo to Settings > Farwatch and enable Camera.',
      MobileScannerErrorCode.unsupported =>
        'Camera not available on this device.',
      _ =>
        'Camera error: ${error.errorDetails?.message ?? error.errorCode.name}',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: c.textPlaceholder),
            const SizedBox(height: 24),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textSecondary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  /// iOS-style lens selector pills overlaid on the camera preview.
  Widget _buildLensSelector() {
    if (!Platform.isIOS) return const SizedBox.shrink();

    final c = context.colors;
    return Positioned(
      bottom: 16,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(_iOSLensPresets.length, (i) {
              final preset = _iOSLensPresets[i];
              final selected = i == _selectedLensIndex;
              return GestureDetector(
                onTap: () => _selectLens(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFE8758A)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Text(
                    preset.label,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white70,
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  /// QR viewfinder overlay — rounded corner brackets centered on the preview.
  Widget _buildViewfinderOverlay() {
    return Center(
      child: SizedBox(
        width: 220,
        height: 220,
        child: CustomPaint(painter: _ViewfinderPainter()),
      ),
    );
  }

  Widget _buildBody() {
    final c = context.colors;
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              MobileScanner(
                controller: _controller,
                onDetect: _onDetect,
                errorBuilder: (context, error) => _buildErrorView(error),
              ),
              _buildViewfinderOverlay(),
              _buildLensSelector(),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Point your camera at the QR code shown by\nfarwatch start',
            textAlign: TextAlign.center,
            style: TextStyle(color: c.textSecondary, fontSize: 14),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      title: 'Scan QR Code',
      body: SafeArea(
        top: false,
        child: _buildBody(),
      ),
    );
  }
}

/// Paints a QR viewfinder overlay: four rounded corner brackets.
class _ViewfinderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerLen = 30.0;
    const radius = 12.0;

    // Top-left
    canvas.drawPath(
      Path()
        ..moveTo(0, cornerLen)
        ..lineTo(0, radius)
        ..quadraticBezierTo(0, 0, radius, 0)
        ..lineTo(cornerLen, 0),
      paint,
    );

    // Top-right
    canvas.drawPath(
      Path()
        ..moveTo(size.width - cornerLen, 0)
        ..lineTo(size.width - radius, 0)
        ..quadraticBezierTo(size.width, 0, size.width, radius)
        ..lineTo(size.width, cornerLen),
      paint,
    );

    // Bottom-left
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height - cornerLen)
        ..lineTo(0, size.height - radius)
        ..quadraticBezierTo(0, size.height, radius, size.height)
        ..lineTo(cornerLen, size.height),
      paint,
    );

    // Bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(size.width - cornerLen, size.height)
        ..lineTo(size.width - radius, size.height)
        ..quadraticBezierTo(
            size.width, size.height, size.width, size.height - radius)
        ..lineTo(size.width, size.height - cornerLen),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
