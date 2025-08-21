import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Reusable full-screen QR scanner modal.
/// Usage:
///   final result = await QrScannerModal.open(context);
///   if (result != null) { /* handle scanned string */ }
class QrScannerModal extends StatefulWidget {
  const QrScannerModal({super.key});

  /// Opens the scanner as a full-screen modal route and resolves with
  /// the first detected QR/barcode string, or null if dismissed.
  static Future<String?> open(BuildContext context) {
    return Navigator.of(context).push<String>(
      PageRouteBuilder<String>(
        fullscreenDialog: true,
        opaque: true,
        barrierDismissible: false,
        transitionDuration: const Duration(milliseconds: 250),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (context, animation, secondaryAnimation) => const QrScannerModal(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  State<QrScannerModal> createState() => _QrScannerModalState();
}

class _QrScannerModalState extends State<QrScannerModal> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: [BarcodeFormat.qrCode, BarcodeFormat.aztec, BarcodeFormat.dataMatrix],
  );

  bool _handled = false;
  bool _torchOn = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    // Take the first barcode with a non-empty raw value.
    for (final b in capture.barcodes) {
      final value = b.rawValue;
      if (value != null && value.isNotEmpty) {
        _handled = true;
        // Pop with the result after a tiny delay to allow UI update.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).pop<String>(value);
        });
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Camera preview
            MobileScanner(
              controller: _controller,
              fit: BoxFit.cover,
              onDetect: _onDetect,
              errorBuilder: (context, error) {
                return _CameraErrorView(error: error);
              },
            ),

            // Overlay
            IgnorePointer(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black54,
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black38,
                    ],
                  ),
                ),
              ),
            ),

            // Framing guide
            Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.7,
                height: MediaQuery.of(context).size.width * 0.7,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white70, width: 2),
                ),
              ),
            ),

            // Top bar: Close
            Positioned(
              top: 8,
              left: 8,
              child: IconButton.filled(
                style: const ButtonStyle(
                  backgroundColor: MaterialStatePropertyAll(Colors.black54),
                ),
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop<String>(null),
                tooltip: 'Close',
              ),
            ),

            // Bottom controls: torch, flip camera
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                          // Torch toggle without live listen (mobile_scanner v7.0.1)
                  _RoundControlButton(
                    icon: _torchOn ? Icons.flash_on : Icons.flash_off,
                    label: 'Torch',
                    onPressed: () async {
                      await _controller.toggleTorch();
                      if (mounted) {
                        setState(() {
                          _torchOn = !_torchOn;
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  const _RoundControlButton({required this.icon, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filled(
          style: const ButtonStyle(
            backgroundColor: MaterialStatePropertyAll(Colors.black54),
          ),
          onPressed: onPressed,
          icon: Icon(icon, color: Colors.white),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }
}

class _CameraErrorView extends StatelessWidget {
  final MobileScannerException error;
  const _CameraErrorView({required this.error});

  @override
  Widget build(BuildContext context) {
    String message = 'Camera error';
    switch (error.errorCode) {
      case MobileScannerErrorCode.permissionDenied:
        message = 'Camera permission denied. Please allow camera access in Settings.';
        break;
      case MobileScannerErrorCode.unsupported:
        message = 'This device does not support camera scanning.';
        break;
      default:
        message = error.errorDetails?.toString() ?? message;
        break;
    }

    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.white70, size: 48),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.of(context).pop<String>(null),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
