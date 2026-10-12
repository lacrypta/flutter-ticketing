import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import 'lnurl.dart';

/// A client with no base URL and no NIP-98 interceptor. Prize and card hosts
/// are not the ticketing API.
final lnurlTransportProvider = Provider<LnurlTransport>((ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: const Duration(seconds: 20),
      responseType: ResponseType.json,
      headers: const {'Accept': 'application/json'},
    ),
  );
  ref.onDispose(dio.close);
  return DioLnurlTransport(dio);
});

final cardPayLinkProvider = Provider<CardPayLink>(
  (ref) => CardPayLink(ref.watch(lnurlTransportProvider)),
);

final lnurlPayerProvider = Provider<LnurlPayer>(
  (ref) => LnurlPayer(ref.watch(lnurlTransportProvider)),
);
