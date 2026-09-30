import 'package:flutter/services.dart';

/// The built-in ZCS thermal printer on Ciontek terminals (Z92, CS30Pro).
///
/// Talks to `MainActivity.kt`. On any other device — a plain Android phone, an
/// emulator, iOS — [isAvailable] is false and printing is skipped. That is a
/// normal state, not an error: the door still works without a printer.
class PrinterChannel {
  static const MethodChannel _ch = MethodChannel('ticketing/printer');

  static Future<bool> isAvailable() async {
    try {
      return await _ch.invokeMethod<bool>('isAvailable') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Prints one benefit voucher. Returns null on success, or a message to show.
  ///
  /// [block], [btcUsd] and [satArs] are the cached market lines. Empty means
  /// the cache is still cold — the voucher prints without them rather than
  /// waiting on the network.
  static Future<String?> printVoucher({
    required String gift,
    required String event,
    required String date,
    required String ticket,
    Uint8List? image,
    String? block,
    String? btcUsd,
    String? satArs,
    String? lnurl,
    String? claimLine,
  }) async {
    try {
      final code = await _ch.invokeMethod<int>('printVoucher', {
        'gift': gift,
        'event': event,
        'date': date,
        'ticket': ticket,
        // Pre-decoded 1-bit PNG bytes; null when there is no artwork or the
        // fetch failed. Never blocks the voucher.
        'image': image,
        'block': block,
        'btcUsd': btcUsd,
        'satArs': satArs,
        'lnurl': lnurl,
        'claimLine': claimLine,
      });
      return _message(code ?? -1);
    } on MissingPluginException {
      return null; // no native side (iOS) — nothing to print on
    } on PlatformException catch (e) {
      return e.message ?? 'Error de impresión';
    }
  }

  /// ZCS SdkResult codes. 0 is success.
  static String? _message(int code) => switch (code) {
    0 => null,
    -1403 => 'Sin papel',
    -1405 => 'Impresora sobrecalentada',
    -1404 => 'Fallo de impresora',
    -100 => 'Impresora no disponible',
    _ => 'Error de impresión (código $code)',
  };
}
