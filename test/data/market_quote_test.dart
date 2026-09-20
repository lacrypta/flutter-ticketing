import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lacrypta_ticketing/data/market/market_cache.dart';
import 'package:lacrypta_ticketing/data/market/market_client.dart';
import 'package:lacrypta_ticketing/data/market/market_quote.dart';
import 'package:mocktail/mocktail.dart';

class _MockClient extends Mock implements MarketClient {}

void main() {
  group('MarketQuote.fromYadio', () {
    test('reads BTC.price as USD and ARS.price as pesos', () {
      final quote = MarketQuote.fromYadio(
        blockHeight: 967856,
        json: {
          'ARS': {'price': 129000000},
          'BTC': {'price': 80888.79},
        },
      );

      expect(quote.blockHeight, 967856);
      expect(quote.btcUsd, 80888.79);
      expect(quote.btcArs, 129000000);
    });

    test('rejects a payload without prices', () {
      expect(
        () => MarketQuote.fromYadio(blockHeight: 1, json: const {}),
        throwsFormatException,
      );
    });

    test('rejects non-positive prices', () {
      expect(
        () => MarketQuote.fromYadio(
          blockHeight: 1,
          json: {
            'ARS': {'price': 0},
            'BTC': {'price': 80000},
          },
        ),
        throwsFormatException,
      );
    });
  });

  group('MarketQuote receipt lines', () {
    test('formats USD in millions and sat in ARS', () {
      const quote = MarketQuote(
        blockHeight: 967856,
        btcUsd: 80888.79,
        btcArs: 129000000,
      );

      expect(quote.blockLine, 'Block 967856');
      expect(quote.btcUsdLine, '1 BTC = USD 0.08M');
      expect(quote.satArsLine, '1 sat = ARS 1.29');
    });
  });

  group('MarketClient', () {
    test('joins mempool height with yadio prices', () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.uri.host.contains('mempool')) {
              handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  data: '840000',
                  statusCode: 200,
                ),
              );
            } else {
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  data: const {
                    'ARS': {'price': 129000000},
                    'BTC': {'price': 80000},
                  },
                  statusCode: 200,
                ),
              );
            }
          },
        ),
      );

      final quote = await MarketClient(dio).fetch();
      expect(quote.blockLine, 'Block 840000');
      expect(quote.btcUsdLine, '1 BTC = USD 0.08M');
      expect(quote.satArsLine, '1 sat = ARS 1.29');
    });
  });

  group('MarketCache', () {
    late _MockClient client;
    late ProviderContainer container;

    setUp(() {
      client = _MockClient();
      container = ProviderContainer(
        overrides: [marketClientProvider.overrideWithValue(client)],
      );
      addTearDown(container.dispose);
    });

    test('stores the first successful fetch', () async {
      const quote = MarketQuote(
        blockHeight: 100,
        btcUsd: 80000,
        btcArs: 129000000,
      );
      when(() => client.fetch()).thenAnswer((_) async => quote);

      expect(container.read(marketCacheProvider), isNull);
      await container.read(marketCacheProvider.notifier).refresh();

      expect(container.read(marketCacheProvider), quote);
    });

    test('keeps the last good snapshot when a poll fails', () async {
      const quote = MarketQuote(
        blockHeight: 100,
        btcUsd: 80000,
        btcArs: 129000000,
      );
      when(() => client.fetch()).thenAnswer((_) async => quote);
      await container.read(marketCacheProvider.notifier).refresh();

      when(() => client.fetch()).thenThrow(Exception('yadio down'));
      await container.read(marketCacheProvider.notifier).refresh();

      expect(
        container.read(marketCacheProvider),
        quote,
        reason: 'printing must still have a snapshot after a failed poll',
      );
    });
  });
}
