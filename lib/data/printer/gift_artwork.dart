import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:image/image.dart' as img;

/// Fetches a gift's artwork and reduces it to something a thermal head can
/// actually render: 1-bit, at most [_width] dots wide.
///
/// Best-effort by design — a missing or slow image must never hold up a
/// voucher, so every failure returns null and the caller prints without it.
class GiftArtwork {
  const GiftArtwork(this._dio);

  final Dio _dio;

  /// 58mm head. Same value the logo is authored at.
  static const int _width = 384;

  /// Long enough for a LAN/4G fetch, short enough that a dead CDN doesn't hold
  /// a queue at the door.
  static const Duration _timeout = Duration(seconds: 4);

  static final Map<String, Uint8List?> _cache = {};

  Future<Uint8List?> fetch(String? url) async {
    if (url == null || url.isEmpty) return null;
    if (_cache.containsKey(url)) return _cache[url];

    try {
      // Relative (`/item-type-templates/...`) resolves against the API base.
      final absolute = Uri.parse(url).hasScheme
          ? url
          : '${_dio.options.baseUrl}$url';

      final response = await _dio.getUri<List<int>>(
        Uri.parse(absolute),
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: _timeout,
          sendTimeout: _timeout,
        ),
      );

      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) return _cache[url] = null;

      // Decodes webp/png/jpg — the CDN serves webp today.
      final decoded = img.decodeImage(Uint8List.fromList(bytes));
      if (decoded == null) return _cache[url] = null;

      final scaled = decoded.width > _width
          ? img.copyResize(decoded, width: _width)
          : decoded;

      // Flatten transparency onto white first: alpha over a thermal head
      // otherwise reads as black and prints a solid slab.
      final flat = img.Image(width: scaled.width, height: scaled.height);
      img.fill(flat, color: img.ColorRgb8(255, 255, 255));
      img.compositeImage(flat, scaled);

      // ponytail: plain luminance threshold, no dithering. Fine for flat logo
      // artwork; switch to Floyd-Steinberg if photographic gifts ever appear.
      final mono = img.grayscale(flat);
      for (final pixel in mono) {
        final v = pixel.r > 160 ? 255 : 0;
        pixel.setRgb(v, v, v);
      }

      return _cache[url] = img.encodePng(mono);
    } catch (_) {
      return _cache[url] = null;
    }
  }
}
