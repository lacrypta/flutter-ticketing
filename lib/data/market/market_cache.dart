import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import 'market_client.dart';
import 'market_quote.dart';

final marketDioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      headers: const {'Cache-Control': 'no-store'},
    ),
  );
  ref.onDispose(dio.close);
  return dio;
});

final marketClientProvider = Provider<MarketClient>(
  (ref) => MarketClient(ref.watch(marketDioProvider)),
);

/// Last good quote, refreshed every [MarketConfig.pollInterval].
///
/// Starts fetching the moment anything watches this provider (the app root
/// does, so the cache is warm before the first gift is claimed). A failed
/// poll keeps the previous snapshot — printing reads [state] and never awaits.
class MarketCache extends Notifier<MarketQuote?> {
  @override
  MarketQuote? build() {
    final timer = Timer.periodic(MarketConfig.pollInterval, (_) {
      unawaited(refresh());
    });
    ref.onDispose(timer.cancel);
    unawaited(refresh());
    return null;
  }

  Future<void> refresh() async {
    try {
      final quote = await ref.read(marketClientProvider).fetch();
      if (!ref.mounted) return;
      state = quote;
    } catch (_) {
      // Keep the last good snapshot. A voucher must never wait on, or fail
      // because of, market data.
    }
  }
}

final marketCacheProvider = NotifierProvider<MarketCache, MarketQuote?>(
  MarketCache.new,
);
