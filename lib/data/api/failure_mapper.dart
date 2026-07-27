import 'dart:io';

import 'package:dio/dio.dart';

import '../../core/error/app_exception.dart';

/// The single place API errors become domain errors.
///
/// The status/`error` pairs below were read off the real route handlers:
///
/// | status | `error`              | meaning                                  |
/// |--------|----------------------|------------------------------------------|
/// | 404    | `Ticket inválido`    | token resolves to nothing                |
/// | 403    | `staff_required`     | CSRF/origin gate rejected the mutation   |
/// | 401    | `staff_required`     | not a manager for this organisation      |
/// | 409    | `event_ended`        | event is over; ticket expired            |
/// | 409    | `insufficient_gift`  | stock ran out                            |
/// | 400    | (validation)         | malformed gift body                      |
/// | 500    | (server)             | claim RPC failed                         |
AppException mapDioError(Object error) {
  if (error is! DioException) {
    return ApiException(status: 0, message: error.toString());
  }

  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return const NetworkException('Tiempo de espera agotado');
    case DioExceptionType.connectionError:
      return const NetworkException();
    case DioExceptionType.cancel:
      return const NetworkException('Solicitud cancelada');
    case DioExceptionType.badCertificate:
      return const NetworkException('Certificado inválido');
    case DioExceptionType.unknown:
      if (error.error is SocketException) return const NetworkException();
      return ApiException(status: 0, message: error.message ?? 'Error de red');
    case DioExceptionType.badResponse:
      break;
  }

  final response = error.response;
  final status = response?.statusCode ?? 0;
  final body = response?.data;
  final code = _stringField(body, 'error');
  final detail = _stringField(body, 'detail');

  switch (status) {
    case 404:
      return const InvalidTicketException();
    case 401:
    case 403:
      if (code == 'staff_required') return const StaffRequiredException();
      return ApiException(
        status: status,
        message: detail ?? code ?? 'No autorizado',
        error: code,
        detail: detail,
      );
    case 409:
      if (code == 'event_ended') return const EventEndedException();
      if (code == 'insufficient_gift') return const InsufficientGiftException();
      break;
  }

  return ApiException(
    status: status,
    // The web app surfaces `detail ?? error ?? "Request failed {status}"`;
    // keep that precedence so both apps report the same thing.
    message: detail ?? code ?? 'La solicitud falló ($status)',
    error: code,
    detail: detail,
  );
}

String? _stringField(Object? body, String key) {
  if (body is Map && body[key] is String) return body[key] as String;
  return null;
}
