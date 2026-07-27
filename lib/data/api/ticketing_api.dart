import 'dart:convert';

import 'package:dio/dio.dart';

import '../../core/error/app_exception.dart';
import 'failure_mapper.dart';
import 'ticketing_dto.dart';

/// The whole ticketing backend: four endpoints, no SDK.
///
/// Auth note: for events without `staff_checkin_required`, **the ticket code in
/// the path is the only credential** — there is no header, cookie or key. That
/// is the server's design, not an omission here. See README → "Security".
class TicketingApi {
  const TicketingApi(this._dio);

  final Dio _dio;

  /// `GET /api/checkin/{code}` — status of one entrada.
  Future<CheckinStatusDto> status(String token) => _guard(
    () async => CheckinStatusDto.fromJson(
      await _getJson('/api/checkin/${_encode(token)}'),
    ),
  );

  /// `POST /api/checkin/{code}` — claim this entrada.
  ///
  /// Idempotent: a second call returns `already_checked_in` rather than
  /// failing, which is precisely what makes replaying a queued check-in safe.
  Future<CheckinResultDto> checkin(String token) => _guard(() async {
    final response = await _dio.postUri<Map<String, dynamic>>(
      _uri('/api/checkin/${_encode(token)}'),
    );
    return CheckinResultDto.fromJson(response.data ?? const {});
  });

  /// `GET /api/checkin/{code}/gifts` — remaining benefits for this attendee.
  Future<GiftData> gifts(String token) => _guard(() async {
    final json = await _getJson('/api/checkin/${_encode(token)}/gifts');
    return parseGiftData(json['gift_data']);
  });

  /// `POST /api/checkin/{code}/gifts/consume` — claim [quantity] of [giftId].
  ///
  /// Returns the **remaining** counts after the operation, which replace local
  /// state wholesale rather than being subtracted from it.
  ///
  /// Unlike check-in this is **not idempotent** — replaying it consumes twice.
  /// The outbox must therefore never blind-retry a consume whose response was
  /// lost; see `domain/outbox`.
  Future<GiftData> consumeGift(
    String token,
    String giftId, {
    int quantity = 1,
  }) => _guard(() async {
    // Serialised here, not handed to Dio as a Map, because NIP-98 signs a hash
    // of the exact body bytes (see Nip98Interceptor).
    //
    // The web app deliberately omits Content-Type to keep the request a CORS
    // "simple request"; the server reads `await request.text()` and parses it
    // itself, so it accepts either. From a native client there is no preflight
    // to avoid, so we send the honest content type.
    final response = await _dio.postUri<Map<String, dynamic>>(
      _uri('/api/checkin/${_encode(token)}/gifts/consume'),
      data: jsonEncode({giftId: quantity}),
      options: Options(contentType: Headers.jsonContentType),
    );
    return parseGiftData(response.data?['gift_data']);
  });

  Future<Map<String, dynamic>> _getJson(String path) async {
    final response = await _dio.getUri<Map<String, dynamic>>(_uri(path));
    return response.data ?? const {};
  }

  Uri _uri(String path) => Uri.parse('${_dio.options.baseUrl}$path');

  /// Tokens can legitimately contain `/` (the parser keeps deeper paths), so
  /// they must be encoded into a single path segment.
  static String _encode(String token) => Uri.encodeComponent(token);

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on AppException {
      rethrow;
    } catch (error) {
      throw mapDioError(error);
    }
  }
}
