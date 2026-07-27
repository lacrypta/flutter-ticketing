import 'package:flutter/material.dart';

import '../../core/theme/lc_colors.dart';

/// The La Crypta isotype: a flat-based arch — a crypt/vault silhouette — with
/// three horizontal ledger slots cut from its right edge, forming a stepped
/// profile that reads as a stylised "C".
///
/// Transcribed by hand from `assets/logos/lacrypta-iso.svg` (a single path,
/// viewBox `0 0 82.04 94.42`) so the mark costs no SVG dependency, tints with
/// [color], and stays crisp at any size. The web app hot-links this from
/// raw.githubusercontent.com at runtime; we deliberately do not.
class LcIsoMark extends StatelessWidget {
  const LcIsoMark({
    this.size = 32,
    this.color = LcColors.textPrimary,
    super.key,
  });

  final double size;
  final Color color;

  static const Size _viewBox = Size(82.04, 94.42);

  @override
  Widget build(BuildContext context) {
    final height = size;
    final width = height * _viewBox.width / _viewBox.height;
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(painter: _IsoPainter(color)),
    );
  }
}

class _IsoPainter extends CustomPainter {
  const _IsoPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.height / LcIsoMark._viewBox.height;
    canvas.scale(scale);

    final path = Path()
      ..moveTo(20.06, 85.85)
      ..lineTo(20.06, 76.32)
      ..lineTo(82, 76.32)
      ..lineTo(82, 69.44)
      ..lineTo(33.73, 69.44)
      ..lineTo(33.73, 59.91)
      ..lineTo(82, 59.91)
      ..lineTo(82, 53)
      ..lineTo(45.58, 53)
      ..lineTo(45.58, 43.5)
      ..lineTo(82, 43.5)
      ..lineTo(82, 43.37)
      // The dome. The second curve is the SVG's `S` shorthand, expanded: its
      // first control point is the reflection of the previous curve's second
      // control point about the join at (41, 0) → (18.32, 0).
      ..cubicTo(82, 20.72, 63.68, 0, 41, 0)
      ..cubicTo(18.32, 0, 0, 20.72, 0, 43.37)
      ..lineTo(0, 94.42)
      ..lineTo(82, 94.42)
      ..lineTo(82, 85.85)
      ..close();

    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_IsoPainter oldDelegate) => oldDelegate.color != color;
}

/// The horizontal lockup: isotype + "la crypta" wordmark.
///
/// Used in the persistent header. The wordmark is set in Standerd rather than
/// traced, which keeps it a single tintable text run and lets it inherit text
/// scaling.
class LcWordmark extends StatelessWidget {
  const LcWordmark({
    this.height = 26,
    this.color = LcColors.textPrimary,
    super.key,
  });

  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        LcIsoMark(size: height, color: color),
        SizedBox(width: height * 0.32),
        Text(
          'la crypta',
          style: TextStyle(
            fontFamily: 'Standerd',
            fontSize: height * 0.82,
            fontWeight: FontWeight.w700,
            height: 1,
            letterSpacing: -height * 0.03,
            color: color,
          ),
        ),
      ],
    );
  }
}
