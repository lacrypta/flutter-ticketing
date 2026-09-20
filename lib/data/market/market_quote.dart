import '../../core/config/app_config.dart';

/// A snapshot of the feeds a gift voucher prints.
///
/// Built by [MarketClient] and held by the cache so a claim never waits on
/// mempool or yadio — printing reads whatever was last fetched.
class MarketQuote {
  const MarketQuote({
    required this.blockHeight,
    required this.btcUsd,
    required this.btcArs,
  });

  final int blockHeight;

  /// One bitcoin, in US dollars.
  final double btcUsd;

  /// One bitcoin, in Argentine pesos (yadio parallel/P2P, not the official FX).
  final double btcArs;

  String get blockLine => 'Block $blockHeight';

  /// `1 BTC = USD 0.08M` — millions, two decimal places, always a dot.
  String get btcUsdLine {
    final millions = btcUsd / 1e6;
    return '1 BTC = USD ${millions.toStringAsFixed(2)}M';
  }

  /// `1 sat = ARS 1.29`
  String get satArsLine {
    final sat = btcArs / MarketConfig.satsPerBtc;
    return '1 sat = ARS ${sat.toStringAsFixed(2)}';
  }

  /// Yadio's `/json/ARS` payload carries both legs: `ARS.price` is BTC in
  /// pesos, `BTC.price` is BTC in dollars. One request, both receipt lines.
  factory MarketQuote.fromYadio({
    required int blockHeight,
    required Map<String, dynamic> json,
  }) {
    final ars = _object(json['ARS']);
    final btc = _object(json['BTC']);
    final btcArs = ars['price'];
    final btcUsd = btc['price'];
    if (btcArs is! num || btcUsd is! num) {
      throw const FormatException('yadio: missing prices');
    }
    if (btcArs <= 0 || btcUsd <= 0) {
      throw const FormatException('yadio: non-positive prices');
    }
    return MarketQuote(
      blockHeight: blockHeight,
      btcUsd: btcUsd.toDouble(),
      btcArs: btcArs.toDouble(),
    );
  }

  static Map<String, dynamic> _object(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const FormatException('yadio: missing ARS/BTC objects');
  }

  @override
  bool operator ==(Object other) =>
      other is MarketQuote &&
      other.blockHeight == blockHeight &&
      other.btcUsd == btcUsd &&
      other.btcArs == btcArs;

  @override
  int get hashCode => Object.hash(blockHeight, btcUsd, btcArs);
}
