import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/lc_colors.dart';
import '../../core/theme/lc_metrics.dart';
import '../../core/theme/lc_typography.dart';
import '../../domain/ticket/ticket.dart';
import '../../ui/components/lc_screen.dart';
import '../../ui/components/lc_surface.dart';
import '../../ui/components/lc_tabular.dart';
import 'history_controller.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({required this.onBack, required this.onOpen, super.key});

  final VoidCallback onBack;
  final void Function(String token) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(historyProvider);
    final successes = ref.watch(historySuccessCountProvider);

    return LcScreen(
      onBack: onBack,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: LcSpace.md),
          const LcEyebrow('esta sesión'),
          const SizedBox(height: LcSpace.sm),
          Text('Historial', style: LcType.h1),
          const SizedBox(height: LcSpace.lg),
          LcCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                LcTabular('$successes', style: LcType.statNumber),
                const SizedBox(width: LcSpace.md),
                Expanded(
                  child: Text(
                    successes == 1 ? 'check-in exitoso' : 'check-ins exitosos',
                    style: LcType.caption,
                  ),
                ),
                LcTabular(
                  '${records.length}',
                  style: LcType.h3.copyWith(color: LcColors.textMuted),
                ),
                const SizedBox(width: LcSpace.sm),
                Text('escaneos', style: LcType.caption),
              ],
            ),
          ),
          const SizedBox(height: LcSpace.lg),
          if (records.isEmpty)
            LcCard(
              child: Text(
                'Todavía no escaneaste ninguna entrada.',
                style: LcType.bodyMuted,
              ),
            )
          else
            for (final record in records) ...[
              _HistoryRow(record: record, onTap: () => onOpen(record.token)),
              const SizedBox(height: LcSpace.sm),
            ],
          const SizedBox(height: LcSpace.xxl),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.record, required this.onTap});

  final ScanRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (record.status) {
      ScanStatus.checkedIn => ('Checkeado', LcColors.accent),
      ScanStatus.alreadyCheckedIn => ('Ya checkeado', LcColors.amber),
      ScanStatus.invalid => ('Inválido', LcColors.danger),
      ScanStatus.staffRequired => ('Requiere staff', LcColors.amber),
      ScanStatus.eventEnded => ('Evento terminado', LcColors.amber),
      ScanStatus.pending => ('Pendiente', LcColors.info),
    };

    return LcCard(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.attendeeName?.isNotEmpty == true
                      ? record.attendeeName!
                      : record.token,
                  style: LcType.body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                LcTabular(
                  DateFormat('HH:mm').format(record.scannedAt),
                  style: LcType.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: LcSpace.sm),
          LcStatusPill(label, color: color),
        ],
      ),
    );
  }
}
