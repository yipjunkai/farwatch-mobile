import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/pairing.dart';
import 'terminal_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _processed = false;
  final _manualController = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    _manualController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_processed) return;

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null) continue;

      if (raw.startsWith('termrelay://')) {
        _processed = true;
        _navigateWithUri(raw);
        return;
      }
    }
  }

  void _navigateWithUri(String uri) {
    try {
      final pairing = PairingUri.parse(uri);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => TerminalScreen(pairing: pairing),
        ),
      );
    } catch (e) {
      _processed = false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid pairing URI: $e')),
      );
    }
  }

  void _showManualEntry() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Paste pairing URI',
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _manualController,
              decoration: const InputDecoration(
                hintText: 'termrelay://pair?...',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                final text = _manualController.text.trim();
                if (text.isNotEmpty) _navigateWithUri(text);
              },
              child: const Text('Connect'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Enter manually',
            onPressed: _showManualEntry,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Point your camera at the QR code shown by\nterminal-relay start',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
