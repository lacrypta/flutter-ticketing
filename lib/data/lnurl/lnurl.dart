import 'dart:convert';

import 'package:bech32/bech32.dart';
import 'package:dio/dio.dart';

import '../../core/error/app_exception.dart';

export '../../core/error/app_exception.dart' show LnurlException;

/// Segwit addresses cap bech32 at 90 characters. LNURL does not — a withdraw
/// link is a URL, and a real one is longer than that. The package default
/// rejects it as `TooLong`, which we were reporting as a missing pay link.
const int _maxBech32Length = 4096;

/// A card writes `lnurlw://{link}`. `{link}` is the LUD-03 endpoint: a full
/// `https://` URL, or a host and path fetched over HTTPS.
Uri lnurlwUri(String source) {
  final value = source.trim();
  const prefix = 'lnurlw://';
  if (!value.toLowerCase().startsWith(prefix)) {
    throw const LnurlException('Se esperaba lnurlw://{link}');
  }
  var link = value.substring(prefix.length).trim();
  if (link.isEmpty) {
    throw const LnurlException('Se esperaba lnurlw://{link}');
  }
  if (link.toLowerCase().startsWith('lnurl1')) return decodeLnurl(link);
  if (!link.contains('://')) link = 'https://$link';
  final uri = Uri.tryParse(link);
  if (uri == null ||
      (uri.scheme != 'https' && uri.scheme != 'http') ||
      uri.host.isEmpty) {
    throw LnurlException('El link de la tarjeta no es una URL', value);
  }
  return uri;
}

/// Turns an `lnurlp://` pay link, an `lnurl1…` string, a `lightning:` link, a
/// lightning address or a raw URL into the HTTPS endpoint a wallet would GET.
///
/// `lnurlp://{link}` is a LUD-06 endpoint. `{link}` is fetched as `https://`
/// unless it is already a URL or a bech32 LNURL.
Uri decodeLnurl(String source) {
  var value = _unwrapPayLink(source.trim());

  final lower = value.toLowerCase();
  if (lower.startsWith('lnurl1')) {
    try {
      final decoded = const Bech32Codec().decode(lower, _maxBech32Length);
      if (decoded.hrp != 'lnurl') {
        throw LnurlException('No se pudo leer el LNURL', value);
      }
      final bytes = _convertBits(decoded.data, 5, 8, pad: false);
      value = utf8.decode(bytes);
      if (value.toLowerCase().startsWith('lnurlp://') ||
          value.toLowerCase().startsWith('lnurlw://') ||
          value.toLowerCase().startsWith('lightning:')) {
        return decodeLnurl(value);
      }
    } on LnurlException {
      rethrow;
    } catch (error) {
      throw LnurlException('No se pudo leer el LNURL: $error', value);
    }
  } else if (value.contains('@') && !value.contains('://')) {
    final parts = value.split('@');
    if (parts.length == 2 && parts[0].isNotEmpty && parts[1].contains('.')) {
      value = 'https://${parts[1]}/.well-known/lnurlp/${parts[0]}';
    }
  }

  final uri = Uri.tryParse(value);
  if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
    throw LnurlException('No se pudo leer el LNURL', value);
  }
  return uri;
}

/// Strips `lightning:` and `lnurlp://` until the remainder is a URL, a bech32
/// LNURL, or a lightning address. A bare host is fetched over HTTPS.
String _unwrapPayLink(String value) {
  while (true) {
    final lower = value.toLowerCase();
    if (lower.startsWith('lightning:')) {
      value = value.substring('lightning:'.length).trim();
      continue;
    }
    if (lower.startsWith('lnurlp://')) {
      value = value.substring('lnurlp://'.length).trim();
      continue;
    }
    break;
  }
  if (value.isEmpty) {
    throw const LnurlException('La tarjeta no tiene un link de cobro');
  }
  final lower = value.toLowerCase();
  if (!value.contains('://') &&
      !lower.startsWith('lnurl1') &&
      !value.contains('@')) {
    if (!value.contains('.')) {
      throw const LnurlException('La tarjeta no tiene un link de cobro');
    }
    value = 'https://$value';
  }
  return value;
}

/// Bech32 `lnurl1…` for a URL. Used by tests and by anything that has to
/// hand a withdraw link back as a scannable string.
String encodeLnurl(String url) {
  final data = _convertBits(utf8.encode(url), 8, 5, pad: true);
  return const Bech32Codec().encode(Bech32('lnurl', data), _maxBech32Length);
}

/// LUD-19: an LNURL-withdraw response may carry a `payLink`, a raw URL
/// (LUD-17) where the same account can be paid.
String payLinkFrom(Map<String, dynamic> json) {
  final status = json['status'];
  if (status is String && status.toUpperCase() == 'ERROR') {
    final reason = json['reason'];
    throw LnurlException(
      reason is String && reason.isNotEmpty
          ? reason
          : 'La tarjeta rechazó la lectura',
    );
  }
  final payLink = json['payLink'];
  if (payLink is! String || payLink.trim().isEmpty) {
    throw const LnurlException('La tarjeta no tiene un link de cobro');
  }
  return payLink.trim();
}

/// Millisatoshis to withdraw, bounded by the prize (LUD-03) and by what the
/// card's pay link is willing to receive (LUD-06).
int withdrawAmountMsats({
  required int? sats,
  required int minWithdrawable,
  required int maxWithdrawable,
  required int minSendable,
  required int maxSendable,
}) {
  if (maxWithdrawable <= 0) {
    throw const LnurlException('Este premio ya no tiene saldo');
  }
  final floor = _max(minWithdrawable, minSendable);
  final ceiling = _min(maxWithdrawable, maxSendable);
  if (floor > ceiling) {
    throw const LnurlException('El monto no entra en la tarjeta');
  }
  final target = (sats != null && sats > 0) ? sats * 1000 : maxWithdrawable;
  if (target >= floor && target <= ceiling) return target;
  if (floor == ceiling) return floor;
  throw const LnurlException('El monto no entra en la tarjeta');
}

int _min(int a, int b) => a < b ? a : b;

int _max(int a, int b) => a > b ? a : b;

/// GET JSON from LNURL endpoints. Kept off the ticketing client: those URLs
/// belong to the prize and the card, and must not carry NIP-98.
abstract class LnurlTransport {
  Future<Map<String, dynamic>> get(Uri uri);
}

class DioLnurlTransport implements LnurlTransport {
  DioLnurlTransport(this._dio);

  final Dio _dio;

  @override
  Future<Map<String, dynamic>> get(Uri uri) async {
    try {
      final response = await _dio.getUri<Object?>(uri);
      return _asMap(response.data);
    } on DioException catch (error) {
      final body = error.response?.data;
      final printed = formatLnurlBody(body);
      if (body is Map) {
        final json = _asMap(body);
        final reason = json['reason'];
        if (reason is String && reason.isNotEmpty) {
          throw LnurlException(reason, printed);
        }
      }
      throw LnurlException(
        'Sin conexión con el premio',
        printed.isEmpty ? null : printed,
      );
    }
  }
}

/// LUD-03 body returned by the URL inside `lnurlw://`.
class CardLud03 {
  const CardLud03({
    required this.url,
    required this.payLink,
    required this.json,
  });

  final String url;
  final String payLink;
  final Map<String, dynamic> json;
}

/// Reads `lnurlw://{link}`, fetches `{link}`, and requires a LUD-03 body
/// that carries `payLink`.
class CardPayLink {
  const CardPayLink(this._transport);

  final LnurlTransport _transport;

  Future<CardLud03> resolve(String payload) async {
    final uri = lnurlwUri(payload);
    late final Map<String, dynamic> json;
    try {
      json = await _transport.get(uri);
    } on LnurlException catch (error) {
      throw LnurlException(error.message, error.response, uri.toString());
    }
    try {
      return CardLud03(
        url: uri.toString(),
        payLink: _lud03PayLink(json),
        json: json,
      );
    } on LnurlException catch (error) {
      throw LnurlException(
        error.message,
        error.response ?? formatLnurlBody(json),
        uri.toString(),
      );
    }
  }
}

String _lud03PayLink(Map<String, dynamic> json) {
  final status = json['status'];
  if (status is String && status.toUpperCase() == 'ERROR') {
    final reason = json['reason'];
    throw LnurlException(
      reason is String && reason.isNotEmpty
          ? reason
          : 'La tarjeta rechazó la lectura',
      formatLnurlBody(json),
    );
  }
  if (json['tag'] != 'withdrawRequest') {
    throw LnurlException('La respuesta no es un LUD-03', formatLnurlBody(json));
  }
  final payLink = json['payLink'];
  if (payLink is! String || payLink.trim().isEmpty) {
    throw LnurlException(
      'La tarjeta no tiene un link de cobro',
      formatLnurlBody(json),
    );
  }
  return payLink.trim();
}

/// Pays a treasure's LUD-03 withdraw into a card's pay link.
///
/// The card does not receive sats directly. LUD-19 only reveals where to pay.
/// We ask that pay link (LUD-06) for an invoice of the prize amount, then hand
/// the invoice to the treasure's withdraw callback. The prize service pays it.
/// Success is `{"status":"OK"}` from that callback — that is the claim.
class LnurlPayer {
  const LnurlPayer(this._transport);

  final LnurlTransport _transport;

  Future<void> payWithdrawTo({
    required String withdrawLnurl,
    required String payLink,
    int? sats,
  }) async {
    final withdraw = await _transport.get(decodeLnurl(withdrawLnurl));
    _rejectError(withdraw, 'Este premio no se puede cobrar');
    final callback = _string(withdraw, 'callback');
    final k1 = _string(withdraw, 'k1');
    if (callback == null || k1 == null) {
      throw LnurlException(
        'Este premio no se puede cobrar',
        formatLnurlBody(withdraw),
      );
    }

    final pay = await _transport.get(decodeLnurl(payLink));
    _rejectError(pay, 'La tarjeta no acepta el cobro');
    final payCallback = _string(pay, 'callback');
    if (payCallback == null) {
      throw LnurlException(
        'La tarjeta no acepta el cobro',
        formatLnurlBody(pay),
      );
    }

    final msats = withdrawAmountMsats(
      sats: sats,
      minWithdrawable: _msat(withdraw['minWithdrawable']),
      maxWithdrawable: _msat(withdraw['maxWithdrawable']),
      minSendable: _msat(pay['minSendable']),
      maxSendable: _msat(pay['maxSendable']),
    );

    final invoice = await _transport.get(
      _withQuery(payCallback, {'amount': '$msats'}),
    );
    _rejectError(invoice, 'No se pudo generar el cobro');
    final pr = _string(invoice, 'pr');
    if (pr == null) {
      throw LnurlException(
        'No se pudo generar el cobro',
        formatLnurlBody(invoice),
      );
    }

    final result = await _transport.get(
      _withQuery(callback, {'k1': k1, 'pr': pr}),
    );
    final status = result['status'];
    if (status is String && status.toUpperCase() == 'OK') return;
    _rejectError(result, 'No se pudo acreditar el premio');
    throw LnurlException(
      'No se pudo acreditar el premio',
      formatLnurlBody(result),
    );
  }
}

void _rejectError(Map<String, dynamic> json, String fallback) {
  final status = json['status'];
  if (status is! String || status.toUpperCase() != 'ERROR') return;
  final reason = json['reason'];
  throw LnurlException(
    reason is String && reason.isNotEmpty ? reason : fallback,
    formatLnurlBody(json),
  );
}

/// Indented JSON when [data] is an object, otherwise its text.
String formatLnurlBody(Object? data) {
  if (data == null) return '';
  if (data is Map || data is List) {
    try {
      return const JsonEncoder.withIndent('  ').convert(data);
    } catch (_) {
      return data.toString();
    }
  }
  final text = data.toString();
  return text == 'null' ? '' : text;
}

String? _string(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) return null;
  return value;
}

int _msat(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return 0;
}

Uri _withQuery(String callback, Map<String, String> extra) {
  final uri = Uri.tryParse(callback);
  if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
    throw const LnurlException('No se pudo cobrar el premio');
  }
  return uri.replace(queryParameters: {...uri.queryParameters, ...extra});
}

Map<String, dynamic> _asMap(Object? data) {
  if (data is Map<String, dynamic>) return data;
  if (data is Map) {
    final result = <String, dynamic>{};
    for (final entry in data.entries) {
      result[entry.key.toString()] = entry.value;
    }
    return result;
  }
  throw const LnurlException('Respuesta inválida del premio');
}

List<int> _convertBits(List<int> data, int from, int to, {required bool pad}) {
  var accumulator = 0;
  var bits = 0;
  final result = <int>[];
  final maxValue = (1 << to) - 1;

  for (final value in data) {
    if (value < 0 || value >> from != 0) {
      throw const FormatException('Valor fuera de rango');
    }
    accumulator = (accumulator << from) | value;
    bits += from;
    while (bits >= to) {
      bits -= to;
      result.add((accumulator >> bits) & maxValue);
    }
  }

  if (pad) {
    if (bits > 0) result.add((accumulator << (to - bits)) & maxValue);
  } else if (bits >= from || ((accumulator << (to - bits)) & maxValue) != 0) {
    throw const FormatException('Padding inválido');
  }

  return result;
}
