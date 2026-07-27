import 'package:flutter/material.dart';

import '../../core/theme/lc_colors.dart';
import '../../core/theme/lc_metrics.dart';
import '../../core/theme/lc_typography.dart';
import 'lc_spinner.dart';
import 'lc_surface.dart';

/// The lime call-to-action.
///
/// Sized for a door: [LcTouch.primary] (72dp) tall by default — well above
/// Material's 48dp — because the operator is one-handed, often gloved, in a
/// dark venue, with a queue behind the person in front of them.
class LcPrimaryButton extends StatelessWidget {
  const LcPrimaryButton({
    required this.label,
    this.onPressed,
    this.icon,
    this.busy = false,
    this.height = LcTouch.primary,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Shows a spinner in place of [icon] and blocks input. Use for in-flight
  /// network work so the operator cannot double-submit a check-in.
  final bool busy;

  final double height;

  bool get _enabled => onPressed != null && !busy;

  @override
  Widget build(BuildContext context) {
    final opacity = _enabled ? 1.0 : 0.65;
    return LcPressable(
      onTap: _enabled ? onPressed : null,
      semanticLabel: label,
      child: Opacity(
        opacity: opacity,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: LcColors.accent,
            borderRadius: LcRadius.cardAll,
            border: Border.all(color: LcColors.accentAlpha(0.46)),
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: LcSpace.lg),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                const LcSpinner(size: 22, color: LcColors.onAccent)
              else if (icon != null)
                Icon(icon, size: 22, color: LcColors.onAccent),
              if (busy || icon != null) const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  style: LcType.button,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The home screen's hero action.
///
/// Taller ([LcTouch.hero], 82dp), with the two things that make it read as
/// *the* thing on the screen: a soft white sheen near the top edge, and a lime
/// glow bleeding into the background beneath it.
class LcHeroButton extends StatelessWidget {
  const LcHeroButton({
    required this.label,
    required this.iconBuilder,
    this.onPressed,
    super.key,
  });

  final String label;

  /// The hero glyph. Passed as a builder because at 52px an icon *font* glyph
  /// is wrong — Lucide bakes a 2px stroke into its outlines, so scaling to 52
  /// yields a ~4.3px stroke. Hero marks are hand-drawn painters instead.
  final WidgetBuilder iconBuilder;

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return LcPressable(
      onTap: onPressed,
      semanticLabel: label,
      child: DecoratedBox(
        // The glow lives on an outer box so it is not clipped by the fill.
        decoration: BoxDecoration(
          borderRadius: LcRadius.cardAll,
          boxShadow: LcShadow.heroGlow,
        ),
        child: Container(
          height: LcTouch.hero,
          decoration: BoxDecoration(
            borderRadius: LcRadius.cardAll,
            border: Border.all(color: LcColors.accentAlpha(0.46)),
            // The CSS stacks `radial-gradient(circle at 50% 24%,
            // rgb(255 255 255/.52), transparent 20%)` *over* a solid `#b5ff1d`.
            // Flutter has no layering here — `gradient` wins outright and
            // `color` is ignored — so the sheen has to be pre-blended onto the
            // accent and the outer stop must be the opaque accent itself.
            // Fading to a transparent accent instead leaves the button a
            // see-through hole with a white smudge in it.
            gradient: RadialGradient(
              center: const Alignment(0, -0.52),
              radius: 0.55,
              colors: [
                Color.alphaBlend(LcColors.whiteAlpha(0.52), LcColors.accent),
                LcColors.accent,
              ],
            ),
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: LcSpace.lg),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              iconBuilder(context),
              const SizedBox(width: 14),
              Flexible(
                child: Text(
                  label,
                  style: LcType.heroButton(width),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A low-emphasis action: translucent white fill, hairline border, no lime.
class LcSecondaryButton extends StatelessWidget {
  const LcSecondaryButton({
    required this.label,
    this.onPressed,
    this.icon,
    this.busy = false,
    this.height = LcTouch.secondary,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  final double height;

  bool get _enabled => onPressed != null && !busy;

  @override
  Widget build(BuildContext context) {
    return LcPressable(
      onTap: _enabled ? onPressed : null,
      semanticLabel: label,
      child: Opacity(
        opacity: _enabled ? 1 : 0.55,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: LcColors.whiteAlpha(0.06),
            borderRadius: LcRadius.cardAll,
            border: Border.all(color: LcColors.whiteAlpha(0.14)),
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: LcSpace.md),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                const LcSpinner(size: 16)
              else if (icon != null)
                Icon(icon, size: 16, color: LcColors.textPrimary),
              if (busy || icon != null) const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label.toUpperCase(),
                  style: LcType.buttonSmall,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
