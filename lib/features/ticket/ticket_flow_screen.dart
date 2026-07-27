import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/lc_colors.dart';
import '../../core/theme/lc_metrics.dart';
import '../../core/theme/lc_typography.dart';
import '../../domain/ticket/gift.dart';
import '../../domain/ticket/ticket.dart';
import '../../ui/components/lc_buttons.dart';
import '../../ui/components/lc_hero_icons.dart';
import '../../ui/components/lc_screen.dart';
import '../../ui/components/lc_spinner.dart';
import '../../ui/components/lc_surface.dart';
import '../../ui/components/lc_tabular.dart';
import '../history/history_controller.dart';
import 'ticket_controller.dart';

/// One route, many phases — the flow is a state machine, not a stack, so
/// putting each phase on the Navigator would let the operator back into a
/// stale check-in screen after the ticket had already been claimed.
class TicketFlowScreen extends ConsumerWidget {
  const TicketFlowScreen({
    required this.onExit,
    required this.onScanAgain,
    required this.onHistory,
    super.key,
  });

  final VoidCallback onExit;
  final VoidCallback onScanAgain;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ticketFlowProvider);
    final controller = ref.read(ticketFlowProvider.notifier);
    final history = ref.watch(historyProvider);

    ref.listen(ticketFlowProvider, (previous, next) {
      if (previous?.phase == next.phase) return;
      _recordHistory(ref, next);
    });

    return LcScreen(
      onBack: () {
        if (state.phase == TicketPhase.checkin ||
            state.phase == TicketPhase.alreadyChecked ||
            state.phase == TicketPhase.invalid ||
            state.phase == TicketPhase.staffRequired ||
            state.phase == TicketPhase.eventEnded) {
          controller.reset();
          onExit();
        } else {
          controller.back();
        }
      },
      historyCount: history.length,
      onHistory: onHistory,
      child: switch (state.phase) {
        TicketPhase.idle || TicketPhase.validating => const _Validating(),
        TicketPhase.benefits => const _LoadingBenefits(),
        TicketPhase.invalid => _Terminal(
          mark: LcColors.danger,
          title: 'Ticket inválido',
          eyebrow: 'no se pudo validar',
          detail:
              state.error ?? 'Este código no corresponde a ninguna entrada.',
          onScanAgain: onScanAgain,
        ),
        TicketPhase.staffRequired => _Terminal(
          mark: LcColors.amber,
          title: 'Requiere staff',
          eyebrow: 'check-in restringido',
          // This is the case most worth getting right: the attendee is fine,
          // the *device* is not authorised. Turning them away would be wrong.
          detail:
              'Este evento exige que el check-in lo haga un encargado. '
              'La entrada es válida — pedí que la registre alguien con '
              'sesión iniciada.',
          onScanAgain: onScanAgain,
        ),
        TicketPhase.eventEnded => _Terminal(
          mark: LcColors.amber,
          title: 'Evento terminado',
          eyebrow: 'entrada vencida',
          detail: 'El evento ya finalizó, así que esta entrada expiró.',
          onScanAgain: onScanAgain,
        ),
        TicketPhase.checkin => _CheckinView(
          state: state,
          onCheckin: controller.checkin,
        ),
        TicketPhase.alreadyChecked => _AlreadyCheckedView(
          state: state,
          onBenefits: controller.loadBenefits,
          onScanAgain: onScanAgain,
        ),
        TicketPhase.gifts => _GiftsView(
          state: state,
          onClaim: (gift) => _claim(ref, gift),
          onScanAgain: onScanAgain,
        ),
      },
    );
  }

  Future<void> _claim(WidgetRef ref, Gift gift) async {
    final claimed = await ref.read(ticketFlowProvider.notifier).claimGift(gift);
    if (claimed == null) return;
    // M2 prints the receipt here, from the same Receipt model both printer
    // backends render.
    ref
        .read(ticketFlowProvider.notifier)
        .recordClaim(
          ClaimedGift(
            gift: claimed,
            claimedAt: DateTime.now(),
            totalArs: 0,
            satPrice: 0,
          ),
        );
  }

  void _recordHistory(WidgetRef ref, TicketFlowState state) {
    final token = state.token;
    if (token == null) return;

    final status = switch (state.phase) {
      TicketPhase.invalid => ScanStatus.invalid,
      TicketPhase.staffRequired => ScanStatus.staffRequired,
      TicketPhase.eventEnded => ScanStatus.eventEnded,
      TicketPhase.alreadyChecked => ScanStatus.alreadyCheckedIn,
      TicketPhase.gifts || TicketPhase.benefits => ScanStatus.checkedIn,
      _ => null,
    };
    if (status == null) return;

    ref
        .read(historyProvider.notifier)
        .record(
          ScanRecord(
            token: token,
            scannedAt: DateTime.now(),
            status: status,
            attendeeName: state.ticket?.attendeeName,
            eventName: state.ticket?.eventName,
          ),
        );
  }
}

// ── Phases ────────────────────────────────────────────────────────────────

class _Validating extends StatelessWidget {
  const _Validating();

  @override
  Widget build(BuildContext context) => const _Centered(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LcSpinner(size: 48),
        SizedBox(height: LcSpace.lg),
        LcEyebrow('validando entrada'),
      ],
    ),
  );
}

class _LoadingBenefits extends StatelessWidget {
  const _LoadingBenefits();

  @override
  Widget build(BuildContext context) => const _Centered(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LcSpinner(size: 48),
        SizedBox(height: LcSpace.lg),
        LcEyebrow('cargando beneficios'),
      ],
    ),
  );
}

class _Terminal extends StatelessWidget {
  const _Terminal({
    required this.mark,
    required this.title,
    required this.eyebrow,
    required this.detail,
    required this.onScanAgain,
  });

  final Color mark;
  final String title;
  final String eyebrow;
  final String detail;
  final VoidCallback onScanAgain;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: LcSpace.lg),
        Center(
          child: Container(
            width: 132,
            height: 132,
            decoration: BoxDecoration(
              color: mark.withValues(alpha: 0.10),
              shape: BoxShape.circle,
              border: Border.all(color: mark.withValues(alpha: 0.42)),
              boxShadow: [
                BoxShadow(
                  color: mark.withValues(alpha: 0.18),
                  blurRadius: 47.63,
                ),
              ],
            ),
            child: Center(child: LcWarningMark(color: mark)),
          ),
        ),
        const SizedBox(height: LcSpace.xl),
        LcEyebrow(eyebrow, color: mark),
        const SizedBox(height: LcSpace.sm),
        Text(title, style: LcType.display(width)),
        const SizedBox(height: LcSpace.md),
        Text(detail, style: LcType.bodyMuted),
        const SizedBox(height: LcSpace.xl),
        LcPrimaryButton(
          label: 'Seguir escaneando',
          icon: LucideIcons.scanLine,
          onPressed: onScanAgain,
        ),
        const SizedBox(height: LcSpace.xxl),
      ],
    );
  }
}

class _CheckinView extends StatelessWidget {
  const _CheckinView({required this.state, required this.onCheckin});

  final TicketFlowState state;
  final Future<void> Function() onCheckin;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final ticket = state.ticket!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: LcSpace.md),
        LcEyebrow('ticket · ${_short(ticket.token)}'),
        const SizedBox(height: LcSpace.sm),
        Text(
          ticket.attendeeName.isEmpty ? 'Entrada' : ticket.attendeeName,
          style: LcType.display(width),
        ),
        const SizedBox(height: LcSpace.lg),
        _TicketFacts(ticket: ticket),
        if (state.error != null) ...[
          const SizedBox(height: LcSpace.md),
          _ErrorNote(state.error!),
        ],
        const SizedBox(height: LcSpace.lg),
        LcPrimaryButton(
          label: state.busy ? 'Haciendo check-in…' : 'Checkin',
          icon: LucideIcons.ticketCheck,
          busy: state.busy,
          onPressed: onCheckin,
        ),
        const SizedBox(height: LcSpace.xxl),
      ],
    );
  }
}

class _AlreadyCheckedView extends StatelessWidget {
  const _AlreadyCheckedView({
    required this.state,
    required this.onBenefits,
    required this.onScanAgain,
  });

  final TicketFlowState state;
  final Future<void> Function() onBenefits;
  final VoidCallback onScanAgain;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final ticket = state.ticket!;
    final at = ticket.checkedInAt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: LcSpace.lg),
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
        const SizedBox(height: LcSpace.xl),
        const LcEyebrow('atención', color: LcColors.amber),
        const SizedBox(height: LcSpace.sm),
        Text('Ya checkeado', style: LcType.display(width)),
        const SizedBox(height: LcSpace.md),
        if (at != null)
          LcTabular(
            DateFormat('dd/MM/yy HH:mm', 'es_AR').format(at),
            style: LcType.h3.copyWith(color: LcColors.amber),
          ),
        const SizedBox(height: LcSpace.lg),
        _TicketFacts(ticket: ticket),
        const SizedBox(height: LcSpace.lg),
        LcPrimaryButton(
          label: 'Cargar beneficios',
          icon: LucideIcons.gift,
          onPressed: onBenefits,
        ),
        const SizedBox(height: LcSpace.md),
        LcSecondaryButton(label: 'Seguir escaneando', onPressed: onScanAgain),
        const SizedBox(height: LcSpace.xxl),
      ],
    );
  }
}

class _GiftsView extends StatelessWidget {
  const _GiftsView({
    required this.state,
    required this.onClaim,
    required this.onScanAgain,
  });

  final TicketFlowState state;
  final Future<void> Function(Gift) onClaim;
  final VoidCallback onScanAgain;

  @override
  Widget build(BuildContext context) {
    final units = state.giftUnits;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: LcSpace.md),
        LcEyebrow('beneficios · ${state.ticket?.attendeeName ?? ''}'),
        const SizedBox(height: LcSpace.sm),
        Text(units.isEmpty ? 'Sin beneficios' : 'Beneficios', style: LcType.h1),
        const SizedBox(height: LcSpace.lg),

        if (state.error != null) ...[
          _ErrorNote(state.error!),
          const SizedBox(height: LcSpace.md),
        ],

        // One row per unit — three pizzas render three rows, so claiming is
        // always one tap and never a quantity stepper.
        for (var i = 0; i < units.length; i++) ...[
          _GiftRow(
            gift: units[i],
            busy: state.claimingGiftId == units[i].id,
            enabled: state.claimingGiftId == null,
            onTap: () => onClaim(units[i]),
          ),
          const SizedBox(height: LcSpace.sm),
        ],

        if (units.isEmpty)
          LcCard(
            child: Text(
              'Esta entrada no tiene beneficios pendientes.',
              style: LcType.bodyMuted,
            ),
          ),

        if (state.claimed.isNotEmpty) ...[
          const SizedBox(height: LcSpace.lg),
          const LcEyebrow('claimeados'),
          const SizedBox(height: LcSpace.sm),
          LcCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final claim in state.claimed)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(claim.gift.label, style: LcType.body),
                        LcTabular(
                          DateFormat('HH:mm').format(claim.claimedAt),
                          style: LcType.caption,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],

        const SizedBox(height: LcSpace.lg),
        LcSecondaryButton(label: 'Seguir escaneando', onPressed: onScanAgain),
        const SizedBox(height: LcSpace.xxl),
      ],
    );
  }
}

class _GiftRow extends StatelessWidget {
  const _GiftRow({
    required this.gift,
    required this.busy,
    required this.enabled,
    required this.onTap,
  });

  final Gift gift;
  final bool busy;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LcPressable(
      onTap: enabled ? onTap : null,
      semanticLabel: 'Entregar ${gift.label}',
      child: Opacity(
        opacity: enabled || busy ? 1 : 0.5,
        child: Container(
          constraints: const BoxConstraints(minHeight: LcTouch.primary),
          padding: const EdgeInsets.symmetric(
            horizontal: LcSpace.md,
            vertical: LcSpace.sm,
          ),
          decoration: BoxDecoration(
            color: LcColors.accent,
            borderRadius: LcRadius.cardAll,
            border: Border.all(color: LcColors.accentAlpha(0.46)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(gift.label, style: LcType.rowTitle),
                    const SizedBox(height: 2),
                    Text('${gift.priceSats} SAT', style: LcType.rowMeta),
                  ],
                ),
              ),
              if (busy)
                const LcSpinner(size: 22, color: LcColors.onAccent)
              else
                const Icon(
                  LucideIcons.printer,
                  size: 22,
                  color: LcColors.onAccent,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared bits ───────────────────────────────────────────────────────────

class _TicketFacts extends StatelessWidget {
  const _TicketFacts({required this.ticket});

  final Ticket ticket;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _Fact(
                label: 'Evento',
                value: ticket.eventName.isEmpty ? '—' : ticket.eventName,
              ),
            ),
            const SizedBox(width: LcSpace.sm),
            Expanded(
              child: _Fact(
                label: 'Estado',
                value: ticket.checkedIn ? 'Ya checkeado' : 'Pendiente',
                valueColor: ticket.checkedIn ? LcColors.amber : LcColors.accent,
              ),
            ),
          ],
        ),
        // Only shown when the buyer actually has more than one entrada —
        // otherwise it is noise. This is why a repeat name can be valid.
        if (ticket.hasInventory) ...[
          const SizedBox(height: LcSpace.sm),
          LcCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Entradas de esta compra', style: LcType.caption),
                LcTabular(
                  '${ticket.ticketsClaimed ?? 0}/${ticket.ticketsTotal ?? 0}',
                  style: LcType.h3,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return LcCard(
      padding: const EdgeInsets.all(12),
      child: SizedBox(
        height: 60,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            LcEyebrow(label),
            Text(
              value,
              style: LcType.h3.copyWith(color: valueColor),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return LcCard(
      borderColor: LcColors.amberAlpha(0.42),
      child: Row(
        children: [
          const Icon(
            LucideIcons.triangleAlert,
            size: 18,
            color: LcColors.amber,
          ),
          const SizedBox(width: LcSpace.sm),
          Expanded(child: Text(message, style: LcType.notice)),
        ],
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      SizedBox(height: 420, child: Center(child: child));
}

String _short(String token) =>
    token.length <= 12 ? token : '${token.substring(0, 10)}…';
