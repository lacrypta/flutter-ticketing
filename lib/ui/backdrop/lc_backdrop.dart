import 'package:flutter/material.dart';

import '../../core/theme/lc_colors.dart';
import '../../core/theme/lc_metrics.dart';

/// The La Crypta backdrop: a lime bloom at the top of the viewport and a
/// perspective grid receding to a horizon along the bottom.
///
/// This is the single most recognisable brand element, so it is worth being
/// precise about. The web original fakes the perspective with a CSS
/// `transform: perspective(520px) rotateX(64deg)` over a tiled background —
/// which cannot be expressed as a Flutter gradient. Instead we project a real
/// ground plane: rows recede with a true perspective divide, and the columns
/// converge on a single vanishing point. That also makes the animation correct
/// (the grid flows *toward* the viewer) rather than merely sliding a texture.
///
/// Wrap a screen's body in this. It paints behind its [child] and never
/// intercepts input.
class LcBackdrop extends StatefulWidget {
  const LcBackdrop({
    required this.child,
    this.animate = true,
    this.showGrid = true,
    this.showBloom = true,
    super.key,
  });

  final Widget child;

  /// Set false on screens that already move a lot (the scanner) so the grid
  /// doesn't compete with the camera feed.
  final bool animate;

  final bool showGrid;
  final bool showBloom;

  @override
  State<LcBackdrop> createState() => _LcBackdropState();
}

class _LcBackdropState extends State<LcBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: LcMotion.gridLoop,
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _controller.repeat();
  }

  @override
  void didUpdateWidget(LcBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPlayback();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPlayback();
  }

  /// A large, slowly-moving skewed texture is a vestibular trigger, so the
  /// motion — not the grid itself — is dropped under reduced-motion.
  void _syncPlayback() {
    final shouldRun =
        widget.animate && !MediaQuery.disableAnimationsOf(context);
    if (shouldRun && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!shouldRun && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: LcColors.background),
        if (widget.showBloom) const IgnorePointer(child: _Bloom()),
        if (widget.showGrid)
          IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: PerspectiveGridPainter(progress: _controller),
                size: Size.infinite,
              ),
            ),
          ),
        widget.child,
      ],
    );
  }
}

/// `radial-gradient(circle at 50% -10%, rgb(181 255 29 / .16), transparent 30%)`
class _Bloom extends StatelessWidget {
  const _Bloom();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -1.2),
          radius: 0.85,
          colors: [
            LcColors.accentAlpha(0.16),
            LcColors.accent.withValues(alpha: 0),
          ],
          stops: const [0, 1],
        ),
      ),
    );
  }
}

/// Projects a ground plane receding to a horizon.
///
/// Rows use a perspective divide `y(n) = horizon + bandHeight * d0 / (d0 + n*step)`,
/// so spacing compresses toward the horizon exactly as a real plane would.
/// Columns are drawn from the vanishing point out to their position on the
/// bottom edge, which is what makes them converge correctly.
class PerspectiveGridPainter extends CustomPainter {
  PerspectiveGridPainter({
    required this.progress,
    this.lineColor,
    this.bandFraction = 0.48,
    this.rowCount = 26,
    this.columnCount = 22,
  }) : super(repaint: progress);

  /// Drives the flow toward the viewer. One full cycle advances the grid by
  /// exactly one row, so the loop is seamless.
  final Animation<double> progress;

  final Color? lineColor;

  /// Share of the viewport height the grid occupies, measured up from the
  /// bottom. CSS used `height: 48vh`.
  final double bandFraction;

  final int rowCount;
  final int columnCount;

  static const double _d0 = 1;
  static const double _step = 0.34;

  @override
  void paint(Canvas canvas, Size size) {
    final band = size.height * bandFraction;
    final horizon = size.height - band;
    final vanishingX = size.width / 2;
    // Deliberately faint. The grid is texture, not decoration — at the web
    // original's weight it competes with the lime CTAs, which are the only
    // thing on screen that is supposed to pull the eye.
    final colour = lineColor ?? LcColors.accentAlpha(0.20);

    final bandRect = Rect.fromLTWH(0, horizon, size.width, band);

    canvas.save();
    canvas.clipRect(bandRect);

    // Every line shares one paint carrying a vertical fade. Without this the
    // columns pile up at the vanishing point into a bright cone that reads as
    // a starburst rather than a floor — and the 1px rows moiré badly as they
    // compress toward the horizon.
    final paint = Paint()
      ..strokeWidth = 1
      ..isAntiAlias = true
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [colour.withValues(alpha: 0), colour],
        stops: const [0.0, 0.75],
      ).createShader(bandRect);

    final phase = progress.value;

    // ── Columns ─────────────────────────────────────────────────────────
    // The CSS band ran 36vw past each edge of the viewport; matching that
    // keeps the outermost lines steep enough to read as a receding plane.
    final halfSpan = size.width * (0.5 + 0.36);
    final columnSpacing = (halfSpan * 2) / columnCount;
    for (var i = 0; i <= columnCount; i++) {
      final bottomX = vanishingX - halfSpan + i * columnSpacing;
      canvas.drawLine(
        Offset(vanishingX, horizon),
        Offset(bottomX, size.height),
        paint,
      );
    }

    // ── Rows ────────────────────────────────────────────────────────────
    for (var n = 0; n < rowCount; n++) {
      final depth = _d0 + (n + phase) * _step;
      final y = horizon + band * _d0 / depth;
      if (y <= horizon || y > size.height) continue;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(PerspectiveGridPainter oldDelegate) =>
      oldDelegate.lineColor != lineColor ||
      oldDelegate.bandFraction != bandFraction ||
      oldDelegate.rowCount != rowCount ||
      oldDelegate.columnCount != columnCount;
}
