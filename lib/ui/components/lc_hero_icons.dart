/// Hand-drawn marks for the three places this app renders an icon above ~40px.
///
/// **Why not the icon font.** Lucide is a 24px, 2px-stroke set, and as an icon
/// *font* the stroke is baked into each outline — so it scales proportionally.
/// The 78px warning triangle would come out with a ~6.5px effective stroke,
/// far heavier than Lucide's own guidance (1.5px above 32px) and visibly
/// chunkier than the web version. These painters take an art-directed
/// [strokeWidth] instead, held near 2.5–3.5px regardless of size.
///
/// Everything at 14–32px uses `lucide_icons_flutter` normally.
library;

import 'package:flutter/material.dart';

import '../../core/theme/lc_colors.dart';

/// Lucide `scan-line`: four corner brackets around a centre rule.
/// Used at 52px on the home hero CTA.
class LcScanMark extends StatelessWidget {
  const LcScanMark({
    this.size = 52,
    this.color = LcColors.onAccent,
    this.strokeWidth = 3,
    super.key,
  });

  final double size;
  final Color color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _ScanPainter(color, strokeWidth)),
  );
}

class _ScanPainter extends CustomPainter {
  const _ScanPainter(this.color, this.strokeWidth);

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final s = size.width;
    final inset = strokeWidth / 2 + s * 0.06;
    final arm = s * 0.22; // bracket leg length
    final r = s * 0.13; // corner radius
    final l = inset, t = inset, rt = s - inset, b = s - inset;

    // Top-left
    canvas.drawPath(
      Path()
        ..moveTo(l, t + arm)
        ..lineTo(l, t + r)
        ..quadraticBezierTo(l, t, l + r, t)
        ..lineTo(l + arm, t),
      paint,
    );
    // Top-right
    canvas.drawPath(
      Path()
        ..moveTo(rt - arm, t)
        ..lineTo(rt - r, t)
        ..quadraticBezierTo(rt, t, rt, t + r)
        ..lineTo(rt, t + arm),
      paint,
    );
    // Bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(rt, b - arm)
        ..lineTo(rt, b - r)
        ..quadraticBezierTo(rt, b, rt - r, b)
        ..lineTo(rt - arm, b),
      paint,
    );
    // Bottom-left
    canvas.drawPath(
      Path()
        ..moveTo(l + arm, b)
        ..lineTo(l + r, b)
        ..quadraticBezierTo(l, b, l, b - r)
        ..lineTo(l, b - arm),
      paint,
    );

    // The scan rule.
    canvas.drawLine(
      Offset(l + s * 0.10, s / 2),
      Offset(rt - s * 0.10, s / 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ScanPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}

/// A rounded warning triangle with a bang. Used at 78px on `already_checked`.
class LcWarningMark extends StatelessWidget {
  const LcWarningMark({
    this.size = 78,
    this.color = LcColors.amber,
    this.strokeWidth = 3.5,
    super.key,
  });

  final double size;
  final Color color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _WarningPainter(color, strokeWidth)),
  );
}

class _WarningPainter extends CustomPainter {
  const _WarningPainter(this.color, this.strokeWidth);

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final inset = strokeWidth / 2 + s * 0.05;
    final apex = Offset(s / 2, inset);
    final left = Offset(inset, s - inset * 1.35);
    final right = Offset(s - inset, s - inset * 1.35);
    final r = s * 0.09;

    // A triangle with all three corners rounded.
    Offset lerp(Offset a, Offset b, double t) =>
        Offset(a.dx + (b.dx - a.dx) * t, a.dy + (b.dy - a.dy) * t);

    double tFor(Offset a, Offset b) => r / (b - a).distance;

    final path = Path()
      ..moveTo(
        lerp(apex, right, tFor(apex, right)).dx,
        lerp(apex, right, tFor(apex, right)).dy,
      )
      ..lineTo(
        lerp(right, apex, tFor(right, apex)).dx,
        lerp(right, apex, tFor(right, apex)).dy,
      )
      ..quadraticBezierTo(
        right.dx,
        right.dy,
        lerp(right, left, tFor(right, left)).dx,
        lerp(right, left, tFor(right, left)).dy,
      )
      ..lineTo(
        lerp(left, right, tFor(left, right)).dx,
        lerp(left, right, tFor(left, right)).dy,
      )
      ..quadraticBezierTo(
        left.dx,
        left.dy,
        lerp(left, apex, tFor(left, apex)).dx,
        lerp(left, apex, tFor(left, apex)).dy,
      )
      ..lineTo(
        lerp(apex, left, tFor(apex, left)).dx,
        lerp(apex, left, tFor(apex, left)).dy,
      )
      ..quadraticBezierTo(
        apex.dx,
        apex.dy,
        lerp(apex, right, tFor(apex, right)).dx,
        lerp(apex, right, tFor(apex, right)).dy,
      )
      ..close();

    canvas.drawPath(path, paint);

    // The bang.
    canvas.drawLine(Offset(s / 2, s * 0.38), Offset(s / 2, s * 0.62), paint);
    canvas.drawCircle(
      Offset(s / 2, s * 0.75),
      strokeWidth / 2,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_WarningPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}

/// Lucide `qr-code`, simplified to its three finder squares plus a data
/// cluster. Used at 40px in the scanner's empty state.
class LcQrMark extends StatelessWidget {
  const LcQrMark({
    this.size = 40,
    this.color = LcColors.textMuted,
    this.strokeWidth = 2.5,
    super.key,
  });

  final double size;
  final Color color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _QrPainter(color, strokeWidth)),
  );
}

class _QrPainter extends CustomPainter {
  const _QrPainter(this.color, this.strokeWidth);

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final stroke = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final fill = Paint()..color = color;

    final box = s * 0.34;
    final inset = strokeWidth / 2;
    final radius = Radius.circular(s * 0.06);

    for (final origin in [
      Offset(inset, inset),
      Offset(s - inset - box, inset),
      Offset(inset, s - inset - box),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(origin & Size(box, box), radius),
        stroke,
      );
    }

    // A few data modules in the free quadrant.
    final unit = s * 0.11;
    for (final cell in const [
      Offset(0, 0),
      Offset(1.6, 0),
      Offset(0, 1.6),
      Offset(1.6, 1.6),
    ]) {
      canvas.drawRect(
        Rect.fromLTWH(
          s * 0.60 + cell.dx * unit,
          s * 0.60 + cell.dy * unit,
          unit,
          unit,
        ),
        fill,
      );
    }
  }

  @override
  bool shouldRepaint(_QrPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}
