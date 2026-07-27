import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'lc_colors.dart';
import 'lc_metrics.dart';
import 'lc_typography.dart';

/// The app's single [ThemeData].
///
/// Two Material 3 defaults actively fight this brand and are switched off here:
///
/// * **`surfaceTint`.** M3 tints every elevated surface with
///   `colorScheme.primary`. Our primary is acid lime, so every card, sheet and
///   dialog would pick up a green wash. Killed globally.
/// * **Elevation shadows.** Depth in this system is carried by surface
///   lightness plus a hairline border. Every component ships `elevation: 0`.
ThemeData buildLcTheme() {
  const scheme = ColorScheme.dark(
    primary: LcColors.accent,
    onPrimary: LcColors.onAccent,
    secondary: LcColors.accent,
    onSecondary: LcColors.onAccent,
    surface: LcColors.surface2,
    onSurface: LcColors.textPrimary,
    error: LcColors.danger,
    onError: LcColors.onAccent,
    outline: LcColors.borderStrong,
    outlineVariant: LcColors.borderSubtle,
    surfaceTint: Colors.transparent, // ← the lime wash, disabled
  );

  final textTheme = LcType.textTheme();

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: LcColors.background,
    canvasColor: LcColors.background,
    fontFamily: LcType.family,
    fontFamilyFallback: LcType.fallback,
    textTheme: textTheme,
    primaryTextTheme: textTheme,

    // Depth is borders and surface lightness, never shadow.
    shadowColor: Colors.transparent,
    splashFactory: InkSparkle.splashFactory,
    highlightColor: LcColors.whiteAlpha(0.04),

    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    ),

    cardTheme: const CardThemeData(
      color: LcColors.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: LcRadius.cardAll,
        side: BorderSide(color: LcColors.border),
      ),
    ),

    dialogTheme: const DialogThemeData(
      backgroundColor: LcColors.surface3,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: LcRadius.modalAll),
    ),

    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: LcColors.surface2,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: LcRadius.sheet),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: LcColors.accent,
        foregroundColor: LcColors.onAccent,
        disabledBackgroundColor: LcColors.accent.withValues(alpha: 0.65),
        disabledForegroundColor: LcColors.onAccent.withValues(alpha: 0.7),
        minimumSize: const Size.fromHeight(LcTouch.primary),
        elevation: 0,
        textStyle: LcType.button,
        shape: const RoundedRectangleBorder(borderRadius: LcRadius.cardAll),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: LcColors.textPrimary,
        backgroundColor: LcColors.whiteAlpha(0.06),
        minimumSize: const Size.fromHeight(LcTouch.secondary),
        elevation: 0,
        textStyle: LcType.buttonSecondary,
        side: BorderSide(color: LcColors.whiteAlpha(0.14)),
        shape: const RoundedRectangleBorder(borderRadius: LcRadius.cardAll),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: LcColors.accent,
        minimumSize: const Size.fromHeight(LcTouch.small),
        textStyle: LcType.buttonSmall,
      ),
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? LcColors.onAccent
            : LcColors.textMuted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? LcColors.accent
            : LcColors.surface4,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(LcColors.border),
    ),

    dividerTheme: const DividerThemeData(
      color: LcColors.borderSubtle,
      thickness: 1,
      space: 1,
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: LcColors.accent,
      linearTrackColor: LcColors.surface4,
      circularTrackColor: Colors.transparent,
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: LcColors.surface3,
      contentTextStyle: LcType.body,
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(borderRadius: LcRadius.cardAll),
    ),

    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        // Predictive back on Android 14+ falls back to the fade-forwards
        // transition on older releases.
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}
