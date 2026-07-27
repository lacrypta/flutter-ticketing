import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/lc_theme.dart';

class LacryptaTicketingApp extends ConsumerWidget {
  const LacryptaTicketingApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'La Crypta Ticketing',
      debugShowCheckedModeBanner: false,
      theme: buildLcTheme(),
      themeMode: ThemeMode.dark,
      routerConfig: ref.watch(routerProvider),
      // Copy is Spanish (es-AR) throughout, including date and number formats.
      locale: const Locale('es', 'AR'),
      supportedLocales: const [Locale('es', 'AR'), Locale('es'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        // The headlines here are enormous by design. Past ~1.3x they stop
        // fitting their slabs and descenders start colliding, so the scale is
        // capped instead of letting the layout break — while still honouring
        // a user who has enlarged text.
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(
              minScaleFactor: 0.9,
              maxScaleFactor: 1.3,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
