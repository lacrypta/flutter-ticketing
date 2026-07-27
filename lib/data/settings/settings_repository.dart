import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_config.dart';

/// Non-secret device settings. Secrets live in `flutter_secure_storage`
/// (see [DeviceIdentity]); nothing here is sensitive.
class Settings {
  const Settings({
    this.nip98Enabled = false,
    this.eventsBaseUrl = AppConfig.eventsBaseUrl,
    this.printerBackend = PrinterBackendChoice.auto,
  });

  /// Default **off**: the check-in route does not validate NIP-98 yet, so
  /// sending the header buys nothing and risks confusing a future middleware.
  /// Flipped on once the device pubkey is registered server-side.
  final bool nip98Enabled;

  final String eventsBaseUrl;
  final PrinterBackendChoice printerBackend;

  Settings copyWith({
    bool? nip98Enabled,
    String? eventsBaseUrl,
    PrinterBackendChoice? printerBackend,
  }) => Settings(
    nip98Enabled: nip98Enabled ?? this.nip98Enabled,
    eventsBaseUrl: eventsBaseUrl ?? this.eventsBaseUrl,
    printerBackend: printerBackend ?? this.printerBackend,
  );
}

/// Which printer path to use. `auto` probes for a built-in ZCS terminal first
/// and falls back to Bluetooth ESC/POS.
enum PrinterBackendChoice { auto, zcs, bluetooth, none }

class SettingsRepository {
  SettingsRepository(this._prefs);

  static const _nip98Key = 'settings.nip98Enabled';
  static const _baseUrlKey = 'settings.eventsBaseUrl';
  static const _printerKey = 'settings.printerBackend';

  final SharedPreferences _prefs;

  Settings read() => Settings(
    nip98Enabled: _prefs.getBool(_nip98Key) ?? false,
    eventsBaseUrl: _prefs.getString(_baseUrlKey) ?? AppConfig.eventsBaseUrl,
    printerBackend: PrinterBackendChoice.values.firstWhere(
      (value) => value.name == _prefs.getString(_printerKey),
      orElse: () => PrinterBackendChoice.auto,
    ),
  );

  Future<void> write(Settings settings) async {
    await _prefs.setBool(_nip98Key, settings.nip98Enabled);
    await _prefs.setString(_baseUrlKey, settings.eventsBaseUrl);
    await _prefs.setString(_printerKey, settings.printerBackend.name);
  }
}

/// Overridden in `main()` once SharedPreferences has loaded, so the rest of the
/// tree can read settings synchronously.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Override sharedPreferencesProvider'),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(sharedPreferencesProvider)),
);

class SettingsController extends Notifier<Settings> {
  @override
  Settings build() => ref.watch(settingsRepositoryProvider).read();

  Future<void> update(Settings settings) async {
    state = settings;
    await ref.read(settingsRepositoryProvider).write(settings);
  }

  Future<void> setNip98Enabled(bool value) =>
      update(state.copyWith(nip98Enabled: value));

  Future<void> setPrinterBackend(PrinterBackendChoice value) =>
      update(state.copyWith(printerBackend: value));
}

final settingsProvider = NotifierProvider<SettingsController, Settings>(
  SettingsController.new,
);
