import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/lc_colors.dart';
import '../../core/theme/lc_metrics.dart';
import '../../core/theme/lc_typography.dart';
import '../../ui/components/lc_buttons.dart';
import '../../ui/components/lc_hero_icons.dart';
import '../../ui/components/lc_screen.dart';
import '../../ui/components/lc_surface.dart';
import '../../ui/components/lc_tabular.dart';
import '../history/history_controller.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({
    required this.onScan,
    required this.onManualEntry,
    required this.onHistory,
    required this.onSettings,
    super.key,
  });

  final VoidCallback onScan;
  final VoidCallback onManualEntry;
  final VoidCallback onHistory;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final history = ref.watch(historyProvider);
    final successes = ref.watch(historySuccessCountProvider);

    return LcScreen(
      historyCount: history.length,
      onHistory: onHistory,
      dock: _Dock(onSettings: onSettings),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: LcSpace.xl),
          const LcEyebrow('control de acceso'),
          const SizedBox(height: LcSpace.sm),
          Text('Escanear', style: LcType.hero(width)),
          const SizedBox(height: LcSpace.xl),
          LcHeroButton(
            label: 'Escanear QR',
            iconBuilder: (_) => const LcScanMark(size: 34),
            onPressed: onScan,
          ),
          const SizedBox(height: LcSpace.md),
          // Deliberately low-emphasis: the camera is the fast path and should
          // stay the obvious one. This is here for the QR that won't scan.
          LcSecondaryButton(
            label: 'Ingresar código',
            icon: LucideIcons.keyboard,
            onPressed: onManualEntry,
          ),
          const SizedBox(height: LcSpace.lg),
          if (successes > 0) _SessionSummary(successes: successes),
          const SizedBox(height: LcSpace.xxl),
        ],
      ),
    );
  }
}

class _SessionSummary extends StatelessWidget {
  const _SessionSummary({required this.successes});

  final int successes;

  @override
  Widget build(BuildContext context) {
    return LcCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          LcTabular('$successes', style: LcType.statNumber),
          const SizedBox(width: LcSpace.md),
          Expanded(
            child: Text(
              successes == 1
                  ? 'check-in exitoso en esta sesión'
                  : 'check-ins exitosos en esta sesión',
              style: LcType.caption,
            ),
          ),
        ],
      ),
    );
  }
}

class _Dock extends StatelessWidget {
  const _Dock({required this.onSettings});

  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'v${AppConfig.gitCommit}',
          style: LcType.footer.copyWith(color: LcColors.textFooter),
        ),
        LcSecondaryButton(
          label: 'Ajustes',
          onPressed: onSettings,
          height: LcTouch.small,
        ),
      ],
    );
  }
}
