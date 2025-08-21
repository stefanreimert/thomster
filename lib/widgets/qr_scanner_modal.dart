import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Reusable full-screen QR scanner modal.
/// Usage:
///   final result = await QrScannerModal.open(context);
///   if (result != null) { /* handle scanned string */ }
typedef QrValidator = Future<QrValidation> Function(String raw);

class QrValidation {
  final String? value;
  final String? error;
  const QrValidation._({this.value, this.error});
  factory QrValidation.valid(String value) => QrValidation._(value: value);
  factory QrValidation.error(String message) => QrValidation._(error: message);
  bool get isValid => value != null;
}

class QrScannerModal extends StatefulWidget {
  final QrValidator? validator;
  const QrScannerModal({super.key, this.validator});

  /// Opens the scanner as a full-screen modal route and resolves with
  /// the first validated (or raw, if no validator) QR/barcode string, or null if dismissed.
  static Future<String?> open(BuildContext context, {QrValidator? validator}) {
    try {
      return Navigator.of(context).push<String>(
        PageRouteBuilder<String>(
          fullscreenDialog: true,
          opaque: true,
          barrierDismissible: false,
          transitionDuration: const Duration(milliseconds: 250),
          reverseTransitionDuration: const Duration(milliseconds: 200),
          pageBuilder: (context, animation, secondaryAnimation) => QrScannerModal(validator: validator),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    } catch (e) {
      // Handle navigation errors gracefully
      return Future.value(null);
    }
  }

  @override
  State<QrScannerModal> createState() => _QrScannerModalState();
}

class _QrScannerModalState extends State<QrScannerModal> with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: [BarcodeFormat.qrCode, BarcodeFormat.aztec, BarcodeFormat.dataMatrix],
  );

  bool _handled = false;
  bool _validating = false;
  bool _torchOn = false;
  String? _errorMessage;
  String? _errorScanned;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Explicitly manage the camera when the app moves between states to avoid
    // iOS RunningBoard assertions and reduce noisy system logs.
    switch (state) {
      case AppLifecycleState.resumed:
        _controller.start();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _controller.stop();
        break;
    }
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_handled || _validating) return;
    // Take the first barcode with a non-empty raw value.
    for (final b in capture.barcodes) {
      final raw = b.rawValue;
      if (raw != null && raw.isNotEmpty) {
        if (widget.validator == null) {
          _handled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.of(context).pop<String>(raw);
          });
          break;
        }

        setState(() {
          _validating = true;
        });
        try {
          final result = await widget.validator!(raw);
          if (!mounted) return;
          if (result.isValid) {
            _handled = true;
            final out = result.value ?? raw;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) Navigator.of(context).pop<String>(out);
            });
          } else {
            setState(() {
              _errorMessage = result.error ?? 'Invalid code';
              _errorScanned = raw;
            });
          }
        } catch (_) {
          if (!mounted) return;
          setState(() {
            _errorMessage = 'Failed to validate code';
            _errorScanned = raw;
          });
        } finally {
          if (mounted) {
            setState(() {
              _validating = false;
            });
          }
        }
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

            // Error overlay over scanner
            if (_errorMessage != null)
              Positioned(
                bottom: 110,
                left: 16,
                right: 16,
                child: _ErrorBanner(
                  message: _errorMessage!,
                  scanned: _errorScanned,
                  onDismiss: () {
                    setState(() {
                      _errorMessage = null;
                      _errorScanned = null;
                    });
                  },
                ),
              ),

            // Bottom controls: torch
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

class _ErrorBanner extends StatelessWidget {
  final String message;
  final String? scanned;
  final VoidCallback onDismiss;
  const _ErrorBanner({required this.message, required this.scanned, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white70),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: onDismiss,
                  icon: const Icon(Icons.close, color: Colors.white70),
                )
              ],
            ),
            if (scanned != null) ...[
              const SizedBox(height: 8),
              const Text('Scanned:', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  scanned!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
