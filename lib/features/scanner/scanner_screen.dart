import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/theme/lc_colors.dart';
import '../../core/theme/lc_metrics.dart';
import '../../core/theme/lc_typography.dart';
import '../../domain/ticket/ticket_token.dart';
import '../../ui/components/lc_buttons.dart';
import '../../ui/components/lc_hero_icons.dart';
import '../../ui/components/lc_surface.dart';

/// Full-screen QR capture.
///
/// The camera is the brightest thing on screen and everything else is a scrim
/// over it, which is the opposite of every other screen in the app — hence no
/// [LcScreen] shell here.
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({required this.onToken, required this.onBack, super.key});

  /// Called once, with the parsed token. The scanner stops itself first.
  final void Function(String token) onToken;

  final VoidCallback onBack;

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );

  /// A single QR sits in frame for many frames, and a door queue means the next
  /// person's code may enter frame while we are still navigating. Latch on the
  /// first accepted token and ignore everything after it.
  bool _handled = false;

  String? _rejected;

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null) continue;

      final token = parseTicketToken(raw);
      if (token == null) {
        // Show why rather than silently doing nothing — a staff member holding
        // a wrong QR to the camera with no feedback will keep holding it.
        if (mounted) setState(() => _rejected = raw);
        continue;
      }

      _handled = true;
      widget.onToken(token);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final frame = size.width * 0.72;

    return Scaffold(
      backgroundColor: LcColors.scannerBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            fit: BoxFit.cover,
            errorBuilder: (context, error) =>
                _CameraError(message: error.errorCode.name),
          ),

          // The spotlight: a transparent rounded rect with an enormous solid
          // shadow, which darkens everything outside it. Cheaper and crisper
          // than a full-screen even-odd path.
          Center(
            child: Container(
              width: frame,
              height: frame,
              decoration: BoxDecoration(
                borderRadius: LcRadius.sheetAll,
                border: Border.all(color: LcColors.accent, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: LcColors.blackAlpha(0.55),
                    spreadRadius: 999,
                  ),
                ],
              ),
            ),
          ),

          const _Scrim(alignment: Alignment.topCenter, heightFactor: 0.38),
          const _Scrim(alignment: Alignment.bottomCenter, heightFactor: 0.48),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(LcSpace.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: LcSecondaryButton(
                      label: 'Cancelar',
                      onPressed: widget.onBack,
                      height: LcTouch.small,
                    ),
                  ),
                  const Spacer(),
                  if (_rejected != null)
                    LcCard(
                      color: LcColors.cardOverCamera,
                      child: Row(
                        children: [
                          const LcQrMark(size: 28, color: LcColors.amber),
                          const SizedBox(width: LcSpace.md),
                          Expanded(
                            child: Text(
                              'Ese QR no es una entrada de La Crypta.',
                              style: LcType.notice,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Center(
                      child: Text(
                        'Apuntá al QR de la entrada',
                        style: LcType.body,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: LcSpace.lg),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Scrim extends StatelessWidget {
  const _Scrim({required this.alignment, required this.heightFactor});

  final Alignment alignment;
  final double heightFactor;

  @override
  Widget build(BuildContext context) {
    final downward = alignment == Alignment.topCenter;
    return Align(
      alignment: alignment,
      child: IgnorePointer(
        child: FractionallySizedBox(
          heightFactor: heightFactor,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: downward ? Alignment.topCenter : Alignment.bottomCenter,
                end: downward ? Alignment.bottomCenter : Alignment.topCenter,
                colors: [
                  LcColors.background.withValues(alpha: 0.92),
                  LcColors.background.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(LcSpace.lg),
        child: LcCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LcQrMark(size: 40, color: LcColors.amber),
              const SizedBox(height: LcSpace.md),
              Text(
                'No se pudo abrir la cámara',
                style: LcType.h3,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: LcSpace.sm),
              Text(message, style: LcType.caption, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
