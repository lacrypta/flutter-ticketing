import 'package:flutter/painting.dart';

/// La Crypta's palette.
///
/// Dark-only — no light theme exists anywhere in the La Crypta ecosystem, and
/// the app is used at night in dark venues. Exactly one saturated colour
/// ([accent]) carries all the signalling; everything else is a step on a
/// near-black ramp. Elevation is expressed as surface lightness plus a hairline
/// border, never as a drop shadow.
abstract final class LcColors {
  // ── Ground ──────────────────────────────────────────────────────────────
  /// Page background. Matches the sibling ticketing PWA.
  static const background = Color(0xFF090909);

  /// The scanner is a half-step darker so the camera feed reads as the
  /// brightest thing on screen.
  static const scannerBackground = Color(0xFF050505);

  // ── Elevation ramp ──────────────────────────────────────────────────────
  static const surface1 = Color(0xFF0A0A0A); // page
  static const surface2 = Color(0xFF0F0F0F); // card, sticky headers
  static const surface3 = Color(0xFF161616); // popover, hover on card
  static const surface4 = Color(0xFF1F1F1F); // pressed, selected row

  /// The card fill.
  ///
  /// The web original is `rgb(18 18 18 / 0.78)` over `#090909` — i.e. *nearly*
  /// opaque already, which is why its `backdrop-filter: blur(16px)` buys almost
  /// nothing. Here the card is fully opaque, because the horizon grid is a real
  /// painted layer rather than a CSS pseudo-element: at 78% the grid lines show
  /// straight through every card and read as noise.
  static const card = Color(0xFF121212);

  /// The translucent variant, for the one place it earns its keep: panels
  /// floating over the live camera feed on the scanner.
  static const cardOverCamera = Color(0xC7121212);

  // ── Borders ─────────────────────────────────────────────────────────────
  /// Hairline inside/around a card. The workhorse — this is what carries
  /// elevation in place of a shadow.
  static const border = Color(0x1CFFFFFF); // white @ 11%

  /// For a border that *is* the control (inputs, outlined buttons). 3.30:1.
  static const borderStrong = Color(0xFF636363);

  /// Barely-there divider inside an already-bordered surface.
  static const borderSubtle = Color(0xFF1A1A1A);

  // ── Accent ──────────────────────────────────────────────────────────────
  /// The acid lime. Every CTA, link, active state, focus ring and badge.
  ///
  /// Nothing is lime for decoration — if it is lime, it is actionable or it is
  /// a live value. lacrypta.ar itself currently renders `#B4F953`; we match the
  /// sibling ticketing PWA's `#B5FF1D` so the two apps read as one product.
  static const accent = Color(0xFFB5FF1D);

  /// Text and icons drawn *on* [accent].
  static const onAccent = Color(0xFF090909);

  // ── Text ────────────────────────────────────────────────────────────────
  static const textPrimary = Color(0xFFFAFAFA);
  static const textDim = Color(0xFFD4D4D8);
  static const textMuted = Color(0xFFA1A1AA);
  static const textFooter = Color(0xFF71717A);

  // ── Status ──────────────────────────────────────────────────────────────
  /// "Already checked in" — the single most common non-happy path at a door,
  /// so it gets its own warm hue rather than reusing [warning].
  static const amber = Color(0xFFFFB86C);

  static const success = Color(0xFF34D399);
  static const warning = Color(0xFFFBBF24);
  static const danger = Color(0xFFF87171);
  static const info = Color(0xFF60A5FA);

  // ── Currency accents ────────────────────────────────────────────────────
  static const ars = Color(0xFF74ACDF); // celeste
  static const usd = Color(0xFF7BE0AD);
  static const sat = Color(0xFFF7931A); // bitcoin orange

  // ── Derived overlays ────────────────────────────────────────────────────
  /// Accent at low alpha — chip fills, the glow ring, grid lines.
  static Color accentAlpha(double opacity) => accent.withValues(alpha: opacity);

  static Color amberAlpha(double opacity) => amber.withValues(alpha: opacity);

  static Color whiteAlpha(double opacity) =>
      const Color(0xFFFFFFFF).withValues(alpha: opacity);

  static Color blackAlpha(double opacity) =>
      const Color(0xFF000000).withValues(alpha: opacity);
}
