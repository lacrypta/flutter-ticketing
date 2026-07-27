import 'package:flutter/material.dart';

import '../../core/theme/lc_colors.dart';
import '../../core/theme/lc_metrics.dart';
import '../../core/theme/lc_typography.dart';

/// The press primitive: a subtle scale-down on tap, using the brand curve.
///
/// Material's ink ripple is wrong for this brand — it washes a light circle
/// across a near-black surface. We suppress it everywhere and express press
/// state as scale plus a surface-lightness step instead.
class LcPressable extends StatefulWidget {
  const LcPressable({
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.98,
    this.semanticLabel,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final String? semanticLabel;

  @override
  State<LcPressable> createState() => _LcPressableState();
}

class _LcPressableState extends State<LcPressable> {
  bool _down = false;

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: _enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onTapDown: _enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: _enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: _enabled ? () => setState(() => _down = false) : null,
        child: AnimatedScale(
          scale: _down && _enabled ? widget.scale : 1,
          duration: LcMotion.fast,
          curve: LcMotion.brand,
          child: widget.child,
        ),
      ),
    );
  }
}

/// The standard surface: translucent near-black fill, 1px hairline border,
/// 8px radius, **no shadow**. Elevation in this system is border + lightness.
class LcCard extends StatelessWidget {
  const LcCard({
    required this.child,
    this.padding = const EdgeInsets.all(LcSpace.md),
    this.color = LcColors.card,
    this.borderColor = LcColors.border,
    this.borderRadius = LcRadius.cardAll,
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;
  final BorderRadius borderRadius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final surface = DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius,
        border: Border.all(color: borderColor),
      ),
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null) return surface;
    return LcPressable(onTap: onTap, child: surface);
  }
}

/// The small uppercase label that sits above a heading.
class LcEyebrow extends StatelessWidget {
  const LcEyebrow(this.text, {this.color, super.key});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: color == null
          ? LcType.eyebrow
          : LcType.eyebrow.copyWith(color: color),
    );
  }
}

/// A status chip. Optionally carries a leading dot, which is how ambient
/// states (NFC listening, sync pending) are signalled without a spinner.
class LcStatusPill extends StatelessWidget {
  const LcStatusPill(
    this.label, {
    this.color = LcColors.accent,
    this.dot = false,
    this.icon,
    super.key,
  });

  final String label;
  final Color color;
  final bool dot;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: LcRadius.pillAll,
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dot) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 7),
            ] else if (icon != null) ...[
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 6),
            ],
            Text(
              label.toUpperCase(),
              style: LcType.pill.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small lime count badge, absolutely positioned by its caller.
class LcCountBadge extends StatelessWidget {
  const LcCountBadge(this.count, {super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 21),
      height: 21,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: const BoxDecoration(
        color: LcColors.accent,
        borderRadius: LcRadius.pillAll,
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: LcType.pill.copyWith(color: LcColors.onAccent),
      ),
    );
  }
}
