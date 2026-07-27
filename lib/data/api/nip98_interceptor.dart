import 'package:dio/dio.dart';

import '../nostr/nip98.dart';

/// Attaches `Authorization: Nostr …` to outgoing requests.
///
/// Ships **disabled by default**. The check-in route currently calls
/// `authenticateRequest` (dashboard JWT only), not `authenticateRequestOrNip98`
/// — so today the header is simply ignored. It becomes load-bearing the moment
/// someone flips that one line server-side and registers this device's pubkey
/// in `users`. See README → "Backend asks".
///
/// Two things here are easy to get wrong and both produce a bare 401:
///
/// * **The signed URL must be the final one.** `options.uri` is resolved after
///   base URL and query parameters are merged, so it is the only correct
///   source. Signing `options.path` would sign a relative string.
/// * **The signed body must be the exact bytes sent.** We require callers to
///   pass an already-serialised `String` body; re-encoding a `Map` here could
///   order keys differently from Dio's own encoder and break the payload hash.
class Nip98Interceptor extends Interceptor {
  Nip98Interceptor({
    required this.isEnabled,
    required this.privateKey,
    this.now,
  });

  /// Read at request time, not construction time, so the settings toggle takes
  /// effect immediately.
  final bool Function() isEnabled;

  /// Returns the device private key (hex), or null if none has been generated.
  final Future<String?> Function() privateKey;

  /// Injectable clock, for tests.
  final DateTime Function()? now;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!isEnabled()) return handler.next(options);

    final key = await privateKey();
    if (key == null) return handler.next(options);

    final data = options.data;
    if (data != null && data is! String) {
      // A Map body would be serialised by Dio *after* this interceptor runs,
      // so we cannot know the exact bytes to hash. Fail loudly in debug rather
      // than shipping a request that will 401 in the field.
      assert(
        false,
        'NIP-98 requires a pre-serialised String body; got ${data.runtimeType}. '
        'Encode with jsonEncode at the call site.',
      );
      return handler.next(options);
    }

    options.headers['Authorization'] = buildNip98Header(
      url: options.uri,
      method: options.method,
      privateKeyHex: key,
      now: now?.call() ?? DateTime.now(),
      body: data as String?,
    );
    handler.next(options);
  }
}
