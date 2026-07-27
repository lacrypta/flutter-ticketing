import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/lc_colors.dart';
import '../../core/theme/lc_metrics.dart';
import '../../core/theme/lc_typography.dart';
import '../backdrop/lc_backdrop.dart';
import '../components/lc_buttons.dart';
import '../components/lc_hero_icons.dart';
import '../components/lc_iso_mark.dart';
import '../components/lc_spinner.dart';
import '../components/lc_surface.dart';
import '../components/lc_tabular.dart';

/// A living style guide.
///
/// Kept in the app (not in `test/`) so the design system can be eyeballed on a
/// real device under real venue lighting, which is the only way to judge
/// whether lime-on-black actually reads at arm's length.
class DesignGallery extends StatelessWidget {
  const DesignGallery({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return Scaffold(
      body: LcBackdrop(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: LcSpace.shellMaxWidth,
              ),
              child: ListView(
                padding: EdgeInsets.symmetric(
                  horizontal: LcSpace.gutter(width),
                  vertical: LcSpace.lg,
                ),
                children: [
                  const _Section('Marca'),
                  const LcWordmark(height: 28),
                  const SizedBox(height: LcSpace.md),
                  const Row(
                    children: [
                      LcIsoMark(size: 44, color: LcColors.accent),
                      SizedBox(width: LcSpace.md),
                      LcIsoMark(size: 32),
                      SizedBox(width: LcSpace.md),
                      LcIsoMark(size: 22, color: LcColors.textMuted),
                    ],
                  ),

                  const _Section('Tipografía'),
                  Text('Escanear', style: LcType.hero(width)),
                  const SizedBox(height: LcSpace.sm),
                  const LcEyebrow('ticket · a1b2c3'),
                  const SizedBox(height: LcSpace.sm),
                  Text('Título de sección', style: LcType.h2),
                  const SizedBox(height: LcSpace.sm),
                  Text(
                    'Cuerpo de texto en Standerd. El peso máximo real es 800 — '
                    'pedir w900 produciría una negrita sintética borrosa.',
                    style: LcType.bodyMuted,
                  ),

                  const _Section('Cifras tabulares'),
                  LcCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const LcEyebrow('sin corregir · los dígitos bailan'),
                        const SizedBox(height: 4),
                        Text('11:11 · 1.111', style: LcType.h2),
                        Text('00:00 · 0.000', style: LcType.h2),
                        const SizedBox(height: LcSpace.md),
                        const LcEyebrow('LcTabular · alineados'),
                        const SizedBox(height: 4),
                        LcTabular('11:11 · 1.111', style: LcType.h2),
                        LcTabular('00:00 · 0.000', style: LcType.h2),
                      ],
                    ),
                  ),

                  const _Section('Acciones'),
                  LcHeroButton(
                    label: 'Escanear QR',
                    iconBuilder: (_) => const LcScanMark(),
                    onPressed: () {},
                  ),
                  const SizedBox(height: LcSpace.md),
                  LcPrimaryButton(
                    label: 'Checkin',
                    icon: LucideIcons.ticketCheck,
                    onPressed: () {},
                  ),
                  const SizedBox(height: LcSpace.md),
                  const LcPrimaryButton(
                    label: 'Haciendo check-in…',
                    busy: true,
                  ),
                  const SizedBox(height: LcSpace.md),
                  LcSecondaryButton(
                    label: 'Verificar beneficios',
                    icon: LucideIcons.gift,
                    onPressed: () {},
                  ),

                  const _Section('Estados'),
                  const Wrap(
                    spacing: LcSpace.sm,
                    runSpacing: LcSpace.sm,
                    children: [
                      LcStatusPill('NFC activo', dot: true),
                      LcStatusPill('Checkeado', color: LcColors.success),
                      LcStatusPill('Ya checkeado', color: LcColors.amber),
                      LcStatusPill('Inválido', color: LcColors.danger),
                      LcStatusPill(
                        '2 pendientes',
                        color: LcColors.info,
                        dot: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: LcSpace.md),
                  const Row(
                    children: [
                      LcSpinner(),
                      SizedBox(width: LcSpace.md),
                      LcCountBadge(3),
                      SizedBox(width: LcSpace.md),
                      LcCountBadge(128),
                    ],
                  ),

                  const _Section('Marcas grandes'),
                  Center(
                    child: Container(
                      width: 132,
                      height: 132,
                      decoration: BoxDecoration(
                        color: LcColors.amberAlpha(0.10),
                        shape: BoxShape.circle,
                        border: Border.all(color: LcColors.amberAlpha(0.42)),
                        boxShadow: LcShadow.amberGlow,
                      ),
                      child: const Center(child: LcWarningMark()),
                    ),
                  ),
                  const SizedBox(height: LcSpace.md),
                  const Center(child: LcQrMark()),

                  const _Section('Superficies'),
                  LcCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const LcEyebrow('asistente'),
                        const SizedBox(height: 6),
                        Text('Agustín Kassis', style: LcType.h3),
                        const SizedBox(height: 4),
                        Text('La Crypta · Hacklab', style: LcType.caption),
                      ],
                    ),
                  ),
                  const SizedBox(height: LcSpace.xxl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: LcSpace.xl, bottom: LcSpace.md),
      child: Row(
        children: [
          LcEyebrow(title, color: LcColors.accent),
          const SizedBox(width: LcSpace.sm),
          const Expanded(child: Divider(color: LcColors.borderSubtle)),
        ],
      ),
    );
  }
}
