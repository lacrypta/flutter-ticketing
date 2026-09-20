import 'package:dio/dio.dart';

import '../../core/config/app_config.dart';
import 'market_quote.dart';

/// Fetches the two public feeds a voucher prints: chain tip and ARS/USD prices.
///
/// Uses its own [Dio] — the ticketing client signs NIP-98 and points at the
/// CRM, neither of which belongs on mempool or yadio.
class MarketClient {
  const MarketClient(this._dio);

  final Dio _dio;

  Future<MarketQuote> fetch() async {
    final blockFuture = _blockHeight();
    final yadioFuture = _yadio();
    return MarketQuote.fromYadio(
      blockHeight: await blockFuture,
      json: await yadioFuture,
    );
  }

  Future<int> _blockHeight() async {
    final response = await _dio.getUri<dynamic>(
      MarketConfig.blockHeight,
      options: Options(responseType: ResponseType.plain),
    );
    final raw = response.data?.toString().trim() ?? '';
    final height = int.tryParse(raw);
    if (height == null || height <= 0) {
      throw FormatException('mempool: bad height "$raw"');
    }
    return height;
  }

  Future<Map<String, dynamic>> _yadio() async {
    final response = await _dio.getUri<Map<String, dynamic>>(
      MarketConfig.btcArs,
    );
    final data = response.data;
    if (data == null || data.isEmpty) {
      throw const FormatException('yadio: empty body');
    }
    return data;
  }
}
