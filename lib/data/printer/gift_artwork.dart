import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

import '../api/api_providers.dart';

/// Fetches a gift's artwork and reduces it to something a thermal head can
/// actually render: 1-bit, at most [_width] dots wide.
///
/// Best-effort by design — a missing or slow image must never hold up a
/// voucher, so every failure returns null and the caller prints without it.
/// Successful rasters stay in [_cache] for the rest of the session so the
/// second pizza of the night is already a bitmap.
class GiftArtwork {
  const GiftArtwork(this._dio);

  final Dio _dio;

  /// 58mm head. Same value the logo is authored at.
  static const int _width = 384;

  /// Long enough for a LAN/4G fetch, short enough that a dead CDN doesn't hold
  /// a queue at the door.
  static const Duration _timeout = Duration(seconds: 4);

  static final Map<String, Uint8List> _cache = {};
  static final Map<String, Future<Uint8List?>> _inflight = {};

  /// Hits [_cache] first, then any fetch already in flight for the same URL,
  /// then the network. Failures are **not** cached: a timeout on the first
  /// attendee must not blank the artwork for everyone after them.
  Future<Uint8List?> fetch(String? url) {
    if (url == null || url.isEmpty) return Future<Uint8List?>.value(null);
    final hit = _cache[url];
    if (hit != null) return Future<Uint8List?>.value(hit);
    return _inflight[url] ??= _load(
      url,
    ).whenComplete(() => _inflight.remove(url));
  }

  /// Warm the cache while the operator is still looking at the gift list, so
  /// a claim's print path is a map lookup rather than a CDN round-trip.
  Future<void> prefetch(Iterable<String?> urls) async {
    final unique = {
      for (final url in urls)
        if (url != null && url.isNotEmpty) url,
    };
    if (unique.isEmpty) return;
    await Future.wait(unique.map(fetch));
  }

  Future<Uint8List?> _load(String url) async {
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
      if (bytes == null || bytes.isEmpty) return null;

      // Decodes webp/png/jpg — the CDN serves webp today.
      final decoded = img.decodeImage(Uint8List.fromList(bytes));
      if (decoded == null) return null;

      final scaled = decoded.width > _width
          ? img.copyResize(decoded, width: _width)
          : decoded;

      // Flatten transparency onto white first: alpha over a thermal head
      // otherwise reads as black and prints a solid slab.
      final flat = img.Image(width: scaled.width, height: scaled.height);
      img.fill(flat, color: img.ColorRgb8(255, 255, 255));
      img.compositeImage(flat, scaled);

      // Monochrome: plain luminance threshold, no dithering. Fine for flat
      // logo artwork; switch to Floyd-Steinberg if photographic gifts ever
      // appear.
      final mono = img.grayscale(flat);
      for (final pixel in mono) {
        final v = pixel.r > 160 ? 255 : 0;
        pixel.setRgb(v, v, v);
      }

      final png = img.encodePng(mono);
      _cache[url] = png;
      return png;
    } catch (_) {
      return null;
    }
  }

  @visibleForTesting
  static void resetCache() {
    _cache.clear();
    _inflight.clear();
  }

  @visibleForTesting
  static bool isCached(String url) => _cache.containsKey(url);
}

final giftArtworkProvider = Provider<GiftArtwork>(
  (ref) => GiftArtwork(ref.watch(dioProvider)),
);
