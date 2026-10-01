import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/config/app_config.dart';

/// On-screen stand-in for the thermal voucher when the device has no printer.
Future<void> showVoucherPreview(
  BuildContext context, {
  required String gift,
  required String event,
  required String date,
  String? imageUrl,
  String? lnurl,
  String? claimLine,
  String? giftId,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (event.isNotEmpty)
                Text(
                  event,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF111111),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              const SizedBox(height: 12),
              _Artwork(url: imageUrl, fallback: gift),
              if (lnurl != null && lnurl.isNotEmpty) ...[
                const SizedBox(height: 16),
                QrImageView(
                  data: lnurl,
                  size: 220,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Color(0xFF111111),
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Color(0xFF111111),
                  ),
                ),
              ],
              if (claimLine != null && claimLine.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  claimLine,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF111111),
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Text(
                date,
                style: const TextStyle(color: Color(0xFF555555), fontSize: 13),
              ),
              if (giftId != null && giftId.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  giftId,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF333333),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Listo'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Artwork extends StatelessWidget {
  const _Artwork({required this.url, required this.fallback});

  final String? url;
  final String fallback;

  @override
  Widget build(BuildContext context) {
    final resolved = _absolute(url);
    if (resolved == null) {
      return Text(
        fallback,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF111111),
          fontSize: 26,
          fontWeight: FontWeight.w800,
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        resolved,
        height: 160,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => Text(
          fallback,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF111111),
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  static String? _absolute(String? url) {
    if (url == null || url.isEmpty) return null;
    if (Uri.parse(url).hasScheme) return url;
    final base = AppConfig.eventsBaseUrl.replaceAll(RegExp(r'/+$'), '');
    return '$base$url';
  }
}
