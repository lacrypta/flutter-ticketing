import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'app.dart';
import 'data/settings/settings_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // A door terminal is held one-handed and never rotated. Locking portrait also
  // stops the camera preview tearing down and re-initialising on a stray turn.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF090909),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // es-AR date formats are used on every result screen.
  await initializeDateFormatting('es_AR');

  // The screen must not sleep between arrivals — an operator waking the device
  // for every attendee is the single most annoying thing a door app can do.
  await WakelockPlus.enable();

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const LacryptaTicketingApp(),
    ),
  );
}
