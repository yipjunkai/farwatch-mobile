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
  MobileScannerController? _controller;
  bool _processed = false;
  final _manualController = TextEditingController();

  // Camera state
  bool _cameraInitialized = false;
  String? _cameraError;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    _controller = MobileScannerController();

    // Listen for permission/error state
    _controller!.addListener(() {
      if (!mounted) return;
      final state = _controller!.value;

      if (state.error != null) {
        setState(() {
          _cameraError = _describeError(state.error!);
          _cameraInitialized = false;
        });
      } else if (state.isInitialized) {
        setState(() {
          _cameraInitialized = true;
          _cameraError = null;
        });
      }
    });

    try {
      await _controller!.start();
      if (mounted && _controller!.value.isInitialized) {
        setState(() {
          _cameraInitialized = true;
          _cameraError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cameraError = e.toString();
        });
      }
    }
  }

  String _describeError(MobileScannerException error) {
    return switch (error.errorCode) {
      MobileScannerErrorCode.permissionDenied =>
        'Camera permission denied.\n\nGo to Settings > Apps > Terminal Relay > Permissions and enable Camera.',
      MobileScannerErrorCode.unsupported =>
        'Camera not available on this device.',
      _ => 'Camera error: ${error.errorDetails?.message ?? error.errorCode.name}',
    };
  }

  @override
  void dispose() {
    _controller?.dispose();
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

  // ---------------------------------------------------------------------------
  // Camera error / permission denied view
  // ---------------------------------------------------------------------------

  Widget _buildCameraError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.no_photography, size: 64, color: Colors.grey[600]),
            const SizedBox(height: 24),
            Text(
              _cameraError!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _cameraError = null;
                  _cameraInitialized = false;
                });
                _controller?.dispose();
                _initCamera();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
            const SizedBox(height: 12),
            Text(
              'Or paste a pairing URI manually',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraLoading() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Starting camera...',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

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
            child: _cameraError != null
                ? _buildCameraError()
                : !_cameraInitialized
                    ? _buildCameraLoading()
                    : MobileScanner(
                        controller: _controller!,
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
