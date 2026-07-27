import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/lc_colors.dart';
import '../../core/theme/lc_metrics.dart';

/// A single-arc spinner rotating at the web app's cadence (0.8s, linear).
///
/// Deliberately not [CircularProgressIndicator]: Material's indeterminate
/// indicator has its own easing and sweep animation, which reads as a
/// different product.
class LcSpinner extends StatefulWidget {
  const LcSpinner({
    this.size = 24,
    this.color = LcColors.accent,
    this.strokeWidth,
    super.key,
  });

  final double size;
  final Color color;
  final double? strokeWidth;

  @override
  State<LcSpinner> createState() => _LcSpinnerState();
}

class _LcSpinnerState extends State<LcSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: LcMotion.spinner,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(
        painter: _ArcPainter(
          turns: _controller,
          color: widget.color,
          strokeWidth: widget.strokeWidth ?? math.max(2, widget.size * 0.11),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter({
    required this.turns,
    required this.color,
    required this.strokeWidth,
  }) : super(repaint: turns);

  final Animation<double> turns;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = strokeWidth / 2;
    final rect =
        Offset(inset, inset) &
        Size(size.width - strokeWidth, size.height - strokeWidth);

    // Faint full ring so the arc reads as travelling around a track.
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = color.withValues(alpha: 0.18)
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke,
    );

    canvas.drawArc(
      rect,
      turns.value * math.pi * 2 - math.pi / 2,
      math.pi * 0.62,
      false,
      Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}
