import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

import 'lc_colors.dart';

/// Spacing, radii, motion and elevation constants.
abstract final class LcSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 14; // the web shell's gutter
  static const double lg = 20;
  static const double xl = 28;
  static const double xxl = 40;

  /// Horizontal page gutter. Tightens on very narrow phones, matching the
  /// web app's `@media (max-width: 390px)` rule.
  static double gutter(double width) => width <= 390 ? 10 : 14;

  /// The shell is centred and capped — a door terminal held one-handed should
  /// never stretch controls to a tablet's full width.
  static const double shellMaxWidth = 520;

  static const double headerHeight = 64;
  static const double dockHeight = 72;
}

abstract final class LcRadius {
  /// Cards and buttons. The single most-used value.
  static const Radius card = Radius.circular(8);
  static const Radius modal = Radius.circular(18);
  static const Radius sheet = Radius.circular(24);
  static const Radius pill = Radius.circular(999);

  static const BorderRadius cardAll = BorderRadius.all(card);
  static const BorderRadius modalAll = BorderRadius.all(modal);
  static const BorderRadius sheetAll = BorderRadius.all(sheet);
  static const BorderRadius pillAll = BorderRadius.all(pill);
}

/// Minimum hit targets. These are deliberately far above Material's 48dp:
/// the operator is one-handed, often gloved, in a dark venue, with a queue.
abstract final class LcTouch {
  static const double hero = 82; // the home "Escanear" CTA
  static const double primary = 72; // every primary action + list rows
  static const double secondary = 54;
  static const double small = 38; // inline text actions only
  static const double nav = 42; // header icon buttons
}

abstract final class LcMotion {
  /// The brand easing curve, `cubic-bezier(0.22, 1, 0.36, 1)`.
  static const Curve brand = Cubic(0.22, 1, 0.36, 1);

  static const Duration fast = Duration(milliseconds: 140);
  static const Duration normal = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 420);

  /// Spinner rotation period — matches the web app's `0.8s linear infinite`.
  static const Duration spinner = Duration(milliseconds: 800);

  /// One full travel of the horizon grid. Deliberately near-subliminal.
  static const Duration gridLoop = Duration(seconds: 24);

  /// The NFC tap pulse.
  static const Duration nfcPulse = Duration(milliseconds: 1800);

  /// Benefits loading is floored at this so a fast response doesn't flash a
  /// spinner for 40ms and read as a glitch. Ported from the web app.
  static const Duration minimumLoad = Duration(milliseconds: 650);
}

/// Shadows.
///
/// Elevation in this system comes from surface lightness and hairline borders.
/// The only legitimate shadows are *glows* around live/actionable things, plus
/// one real shadow under modals.
///
/// CSS blur radius does not map 1:1 to Flutter's [BoxShadow.blurRadius]:
/// Flutter uses `sigma = blurRadius * 0.57735 + 0.5` while CSS uses
/// `sigma = blur / 2`. So `flutterRadius = (cssPx / 2 - 0.5) / 0.57735`.
/// Passing the raw CSS number makes every glow ~17% too soft.
abstract final class LcShadow {
  static double fromCss(double cssPx) => (cssPx / 2 - 0.5) / 0.57735;

  /// Under the hero scan CTA: a tight lime ring plus a wide bloom.
  /// CSS: `0 0 0 5px rgb(181 255 29 / .08), 0 24px 70px rgb(181 255 29 / .18)`.
  static List<BoxShadow> get heroGlow => [
    BoxShadow(
      color: LcColors.accentAlpha(0.08),
      blurRadius: 0,
      spreadRadius: 5,
    ),
    BoxShadow(
      color: LcColors.accentAlpha(0.18),
      blurRadius: 59.75, // CSS 70px
      offset: const Offset(0, 24),
    ),
  ];

  /// Around the 132px amber "already checked in" mark. CSS `0 0 56px @18%`.
  static List<BoxShadow> get amberGlow => [
    BoxShadow(color: LcColors.amberAlpha(0.18), blurRadius: 47.63),
  ];

  /// The one real shadow. CSS `0 16px 46px rgb(0 0 0 / .28)`.
  static List<BoxShadow> get modal => [
    BoxShadow(
      color: LcColors.blackAlpha(0.28),
      blurRadius: 38.97,
      offset: const Offset(0, 16),
    ),
  ];
}
