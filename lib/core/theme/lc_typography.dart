import 'package:flutter/material.dart';

import 'lc_colors.dart';

/// La Crypta's type system, built on **Standerd**.
///
/// Three brand rules are encoded here and must not be worked around:
///
/// 1. **Headings use line-height equal to font-size** (`height: 1.0`) with
///    negative tracking, so a heading block reads as a solid geometric slab.
///    The consequence is that headings carry zero leading — give them explicit
///    margin or descenders will collide with the next line.
/// 2. **The maximum real weight is 800.** Standerd ships Thin..ExtraBold and the
///    brand explicitly disables synthetic bold. The web CSS asks for `950`,
///    which only ever resolved to a *fallback* font's 900. Asking Flutter for
///    [FontWeight.w900] here would smear. Everything "extra bold" is [w800].
/// 3. **Glyph coverage is incomplete.** Confirmed missing from Standerd's cmap:
///    `₿` U+20BF, `✓` U+2713, `⌫` U+232B, `⚡` U+26A1, `★` U+2605, `∞` U+221E.
///    Never put those in UI copy — use an icon. (The PIN keypad's backspace is
///    the concrete trap: as a character it renders as tofu.)
abstract final class LcType {
  static const String family = 'Standerd';

  /// Flutter does **not** apply automatic font fallback to asset fonts, so the
  /// chain has to be declared explicitly or missing glyphs render as tofu
  /// rather than falling through to a system face.
  static const List<String> fallback = <String>[
    'SF Pro Text', // iOS
    'Roboto', // Android
    'Helvetica Neue',
    'Arial',
  ];

  /// Converts CSS `em`-relative tracking to Flutter's absolute
  /// [TextStyle.letterSpacing], which is in logical pixels.
  static double tracking(double em, double fontSize) => em * fontSize;

  static TextStyle _base({
    required double size,
    required FontWeight weight,
    required double height,
    double trackingEm = 0,
    Color color = LcColors.textPrimary,
  }) => TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontSize: size,
    fontWeight: weight,
    height: height,
    letterSpacing: tracking(trackingEm, size),
    color: color,
  );

  // ── Display ────────────────────────────────────────────────────────────
  // Sizes are clamped against the viewport the same way the CSS `clamp()` did.
  // Call these with the available width; they are not const for that reason.

  /// The biggest thing on any screen. CSS `clamp(3.2rem, 18vw, 5.6rem)`.
  static TextStyle hero(double width) => _base(
    size: (width * 0.18).clamp(51.2, 89.6),
    weight: FontWeight.w800,
    height: 0.9,
    trackingEm: -0.035,
  );

  /// Slightly restrained hero, for screens that also carry a data block.
  /// CSS `clamp(2.5rem, 15vw, 4.2rem)`.
  static TextStyle display(double width) => _base(
    size: (width * 0.15).clamp(40, 67.2),
    weight: FontWeight.w800,
    height: 0.92,
    trackingEm: -0.03,
  );

  static final TextStyle h1 = _base(
    size: 32,
    weight: FontWeight.w700,
    height: 1,
    trackingEm: -0.025,
  );

  static final TextStyle h2 = _base(
    size: 24,
    weight: FontWeight.w700,
    height: 1,
    trackingEm: -0.02,
  );

  static final TextStyle h3 = _base(
    size: 20,
    weight: FontWeight.w600,
    height: 1.1,
    trackingEm: -0.015,
  );

  // ── Body ───────────────────────────────────────────────────────────────
  static final TextStyle body = _base(
    size: 15,
    weight: FontWeight.w500,
    height: 1.4,
  );

  static final TextStyle bodyMuted = body.copyWith(color: LcColors.textMuted);

  static final TextStyle notice = _base(
    size: 14.7,
    weight: FontWeight.w500,
    height: 1.4,
    color: LcColors.amber,
  );

  static final TextStyle caption = _base(
    size: 14,
    weight: FontWeight.w500,
    height: 1.3,
    color: LcColors.textMuted,
  );

  static final TextStyle footer = _base(
    size: 11.8,
    weight: FontWeight.w700,
    height: 1.3,
    color: LcColors.textFooter,
  );

  // ── Eyebrow ────────────────────────────────────────────────────────────
  /// The small uppercase label above a heading. Note `letterSpacing: 0` — the
  /// brand deliberately does *not* letterspace its eyebrows, which is unusual
  /// and easy to "fix" by accident.
  static final TextStyle eyebrow = _base(
    size: 12.2,
    weight: FontWeight.w800,
    height: 1.2,
    color: LcColors.textMuted,
  );

  static final TextStyle eyebrowAccent = eyebrow.copyWith(
    color: LcColors.accent,
  );

  // ── Controls ───────────────────────────────────────────────────────────
  /// The hero scan CTA. CSS `clamp(1.35rem, 7vw, 1.9rem)`.
  static TextStyle heroButton(double width) => _base(
    size: (width * 0.07).clamp(21.6, 30.4),
    weight: FontWeight.w800,
    height: 1,
    trackingEm: -0.02,
    color: LcColors.onAccent,
  );

  static final TextStyle button = _base(
    size: 18.4,
    weight: FontWeight.w800,
    height: 1,
    trackingEm: -0.015,
    color: LcColors.onAccent,
  );

  static final TextStyle buttonSecondary = button.copyWith(
    color: LcColors.textPrimary,
  );

  /// Small uppercase action text (`.smallSecondaryButton`).
  static final TextStyle buttonSmall = _base(
    size: 12.5,
    weight: FontWeight.w800,
    height: 1,
    color: LcColors.textPrimary,
  );

  /// A gift row's label.
  static final TextStyle rowTitle = _base(
    size: 17.3,
    weight: FontWeight.w800,
    height: 1,
    trackingEm: -0.015,
    color: LcColors.onAccent,
  );

  /// The uppercase sub-label under a row title ("1 SAT").
  static final TextStyle rowMeta = _base(
    size: 12.5,
    weight: FontWeight.w800,
    height: 1.2,
    color: LcColors.onAccent,
  ).copyWith(color: LcColors.onAccent.withValues(alpha: 0.66));

  /// Status chips and count badges.
  static final TextStyle pill = _base(
    size: 11.5,
    weight: FontWeight.w800,
    height: 1,
  );

  /// A big standalone number (the history counter).
  static final TextStyle statNumber = _base(
    size: 37.6,
    weight: FontWeight.w800,
    height: 0.9,
    trackingEm: -0.03,
  );

  /// Builds the Material [TextTheme]. Most of the app uses the named styles
  /// above directly; this exists so stock Material widgets inherit the brand.
  static TextTheme textTheme() => TextTheme(
    displayLarge: h1,
    displayMedium: h2,
    displaySmall: h3,
    headlineLarge: h1,
    headlineMedium: h2,
    headlineSmall: h3,
    titleLarge: h3,
    titleMedium: body.copyWith(fontWeight: FontWeight.w600),
    titleSmall: caption,
    bodyLarge: body,
    bodyMedium: body,
    bodySmall: caption,
    labelLarge: button.copyWith(color: LcColors.textPrimary),
    labelMedium: buttonSmall,
    labelSmall: eyebrow,
  );
}
