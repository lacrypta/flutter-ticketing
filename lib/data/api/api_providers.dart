import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../nostr/device_identity.dart';
import '../settings/settings_repository.dart';
import 'nip98_interceptor.dart';
import 'ticketing_api.dart';

final deviceIdentityProvider = Provider<DeviceIdentity>(
  (ref) => DeviceIdentity(),
);

final dioProvider = Provider<Dio>((ref) {
  final settings = ref.watch(settingsProvider);
  final identity = ref.watch(deviceIdentityProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: settings.eventsBaseUrl.replaceAll(RegExp(r'/+$'), ''),
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      // Never let a proxy or the platform cache a check-in status: a stale
      // "not checked in" would let the same entrada through twice.
      headers: const {'Cache-Control': 'no-store'},
      responseType: ResponseType.json,
    ),
  );

  dio.interceptors.add(
    Nip98Interceptor(
      // Read through the provider each time so the Settings toggle applies
      // without rebuilding the client.
      isEnabled: () => ref.read(settingsProvider).nip98Enabled,
      privateKey: identity.existingPrivateKey,
    ),
  );

  ref.onDispose(dio.close);
  return dio;
});

final ticketingApiProvider = Provider<TicketingApi>(
  (ref) => TicketingApi(ref.watch(dioProvider)),
);
