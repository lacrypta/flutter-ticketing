import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/lc_colors.dart';
import '../../core/theme/lc_metrics.dart';
import '../../core/theme/lc_typography.dart';
import '../backdrop/lc_backdrop.dart';
import 'lc_iso_mark.dart';
import 'lc_surface.dart';

/// The app shell: brand header, horizon backdrop, centred capped-width body,
/// and an optional pinned footer dock.
///
/// Every screen uses this so the header never re-mounts between phases — the
/// logo and the history badge stay put while content changes underneath, which
/// is what makes the flow feel like one machine rather than a slideshow.
class LcScreen extends StatelessWidget {
  const LcScreen({
    required this.child,
    this.onBack,
    this.historyCount,
    this.onHistory,
    this.dock,
    this.animateBackdrop = true,
    this.showBackdrop = true,
    this.scrollable = true,
    super.key,
  });

  final Widget child;

  /// Null hides the back affordance but keeps its slot, so the logo never
  /// shifts horizontally between screens.
  final VoidCallback? onBack;

  final int? historyCount;
  final VoidCallback? onHistory;

  /// Pinned to the bottom, above the safe area.
  final Widget? dock;

  final bool animateBackdrop;
  final bool showBackdrop;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final gutter = LcSpace.gutter(width);

    final body = Padding(
      padding: EdgeInsets.fromLTRB(gutter, LcSpace.md, gutter, LcSpace.lg),
      child: child,
    );

    return Scaffold(
      backgroundColor: LcColors.background,
      body: LcBackdrop(
        animate: animateBackdrop,
        showGrid: showBackdrop,
        showBloom: showBackdrop,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: LcSpace.shellMaxWidth,
              ),
              child: Column(
                children: [
                  _BrandHeader(
                    onBack: onBack,
                    historyCount: historyCount,
                    onHistory: onHistory,
                    gutter: gutter,
                  ),
                  Expanded(
                    child: scrollable
                        ? SingleChildScrollView(child: body)
                        : body,
                  ),
                  if (dock != null)
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        gutter,
                        0,
                        gutter,
                        LcSpace.md,
                      ),
                      child: dock,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({
    required this.onBack,
    required this.historyCount,
    required this.onHistory,
    required this.gutter,
  });

  final VoidCallback? onBack;
  final int? historyCount;
  final VoidCallback? onHistory;
  final double gutter;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: LcSpace.headerHeight,
      padding: EdgeInsets.symmetric(horizontal: gutter),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: LcColors.border)),
      ),
      child: Row(
        children: [
          // Kept in the layout even when hidden so the wordmark does not jump.
          Visibility(
            visible: onBack != null,
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: _IconButton(
              icon: LucideIcons.arrowLeft,
              onTap: onBack,
              semanticLabel: 'Volver',
            ),
          ),
          const SizedBox(width: LcSpace.sm),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const LcWordmark(height: 20),
                const SizedBox(height: 2),
                Text('ticketing', style: LcType.eyebrow.copyWith(fontSize: 10)),
              ],
            ),
          ),
          if (onHistory != null)
            Stack(
              clipBehavior: Clip.none,
              children: [
                _IconButton(
                  icon: LucideIcons.history,
                  onTap: onHistory,
                  semanticLabel: 'Historial',
                ),
                if ((historyCount ?? 0) > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: LcCountBadge(historyCount!),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return LcPressable(
      onTap: onTap,
      semanticLabel: semanticLabel,
      child: Container(
        width: LcTouch.nav,
        height: LcTouch.nav,
        decoration: BoxDecoration(
          color: LcColors.whiteAlpha(0.055),
          borderRadius: LcRadius.pillAll,
          border: Border.all(color: LcColors.whiteAlpha(0.12)),
        ),
        child: Icon(icon, size: 18, color: LcColors.textPrimary),
      ),
    );
  }
}
