import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/pairing.dart';

/// Dedicated QR scanner screen. Returns a [PairingUri] via Navigator.pop
/// when a valid farwatch:// QR code is scanned.
///
/// Camera only starts when this screen is opened (not on app launch).
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _controller = MobileScannerController();
  bool _processed = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_processed) return;

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null) continue;

      if (raw.startsWith('farwatch://')) {
        _processed = true;
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid pairing URI: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              errorBuilder: (context, error, child) {
                final message = switch (error.errorCode) {
                  MobileScannerErrorCode.permissionDenied =>
                    'Camera permission denied.\n\nGo to Settings > Apps > Farwatch > Permissions and enable Camera.',
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
                        Icon(Icons.no_photography,
                            size: 64, color: Colors.grey[600]),
                        const SizedBox(height: 24),
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style:
                              TextStyle(color: Colors.grey[400], fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Point your camera at the QR code shown by\nfarwatch start',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
