/// Build-time configuration.
///
/// Everything here is overridable with `--dart-define` so a build can be
/// pointed at a staging backend without touching source:
///
/// ```
/// flutter build apk --dart-define=EVENTS_BASE_URL=https://staging.lacrypta.ar
/// ```
abstract final class AppConfig {
  /// The ticketing API. Matches the web app's `VITE_EVENTS_BASE_URL` default.
  static const String eventsBaseUrl = String.fromEnvironment(
    'EVENTS_BASE_URL',
    defaultValue: 'https://events.lacrypta.ar',
  );

  /// Trailing slashes are stripped so path concatenation is unambiguous — and
  /// because NIP-98's `u` tag is compared byte-for-byte, a stray slash there
  /// is an instant 401.
  static Uri apiUri(String path) =>
      Uri.parse('${eventsBaseUrl.replaceAll(RegExp(r'/+$'), '')}$path');

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 15);

  static const String gitCommit = String.fromEnvironment(
    'GIT_COMMIT',
    defaultValue: 'local',
  );
}

/// Market data feeds, used only to price receipts.
abstract final class MarketConfig {
  static final Uri blockHeight = Uri.parse(
    'https://mempool.space/api/blocks/tip/height',
  );

  static final Uri btcArs = Uri.parse('https://api.yadio.io/json/ARS');

  static const Duration pollInterval = Duration(seconds: 60);

  static const int satsPerBtc = 100000000;
}
