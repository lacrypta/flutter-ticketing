import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nfc_manager/nfc_manager.dart';

import '../../core/error/app_exception.dart';
import '../../core/theme/lc_colors.dart';
import '../../core/theme/lc_metrics.dart';
import '../../core/theme/lc_typography.dart';
import '../../data/lnurl/lnurl_providers.dart';
import '../../data/nfc/nfc_card_reader.dart';
import '../../domain/ticket/gift.dart';
import '../../ui/components/lc_spinner.dart';
import '../../ui/components/lc_surface.dart';
import 'ticket_controller.dart';

enum _NfcPhase { idle, reading, paying, success, error, off }

/// Tap-to-claim for sats prizes.
///
/// Shown only while a treasure can still be paid. Android listens as soon as
/// the list is on screen; iOS waits for a press, because Core NFC requires it.
class TreasureNfcPanel extends ConsumerStatefulWidget {
  const TreasureNfcPanel({super.key});

  @override
  ConsumerState<TreasureNfcPanel> createState() => _TreasureNfcPanelState();
}

class _TreasureNfcPanelState extends ConsumerState<TreasureNfcPanel>
    with WidgetsBindingObserver {
  final NfcCardReader _reader = NfcCardReader();

  _NfcPhase _phase = _NfcPhase.idle;
  NfcAvailability _availability = NfcAvailability.unsupported;
  String? _message;
  int? _sats;
  String? _label;
  bool _session = false;
  bool _ready = false;
  bool _holding = false;
  bool _payoutStarted = false;
  TicketFlowController? _controller;
  Timer? _resume;

  bool get _ios => defaultTargetPlatform == TargetPlatform.iOS;

  bool get _mobile =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_mobile) {
      unawaited(_arm());
    } else {
      _ready = true;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _resume?.cancel();
    // A read that never reached the prize service must not leave the row locked.
    // Once the payout has started, the in-flight call still marks the claim.
    if (_holding && !_payoutStarted) _controller?.releaseGift();
    unawaited(_reader.cancel());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _mobile) unawaited(_arm());
  }

  List<Gift> _claimable() => [
    for (final gift in ref.read(ticketFlowProvider).visibleBenefits)
      if (gift.isTreasure && gift.canPrint) gift,
  ];

  Future<void> _arm() async {
    final availability = await _reader.availability();
    if (!mounted) return;
    setState(() {
      _availability = availability;
      _ready = true;
      if (availability == NfcAvailability.disabled &&
          _phase == _NfcPhase.idle) {
        _phase = _NfcPhase.off;
      }
      if (availability == NfcAvailability.enabled && _phase == _NfcPhase.off) {
        _phase = _NfcPhase.idle;
      }
    });
    if (!_ios && availability == NfcAvailability.enabled) unawaited(_listen());
  }

  Future<void> _listen() async {
    if (_session || !mounted || _phase != _NfcPhase.idle) return;
    if (_availability != NfcAvailability.enabled) return;
    if (_claimable().isEmpty) return;
    if (ref.read(ticketFlowProvider).claimingGiftId != null) return;

    _session = true;
    try {
      final raw = await _reader.readOnce(
        prompt: 'Apoyá la tarjeta para cobrar sats',
      );
      if (!mounted) return;
      final gift = _next();
      if (gift == null) return;
      await _claim(gift, raw);
    } on NfcReadCancelled {
      if (mounted && _phase == _NfcPhase.idle) {
        setState(() => _message = null);
      }
    } on NfcException catch (error) {
      _showError(error.message);
    } finally {
      _session = false;
    }
  }

  Gift? _next() {
    if (ref.read(ticketFlowProvider).claimingGiftId != null) return null;
    final gifts = _claimable();
    if (gifts.isEmpty) return null;
    return gifts.first;
  }

  Future<void> _claim(Gift gift, String raw) async {
    final controller = ref.read(ticketFlowProvider.notifier);
    final resolve = ref.read(cardPayLinkProvider).resolve;
    final payer = ref.read(lnurlPayerProvider);
    if (!controller.holdGift(gift.id)) return;
    _controller = controller;
    _holding = true;

    setState(() {
      _phase = _NfcPhase.reading;
      _sats = gift.satsAmount;
      _label = gift.label;
      _message = null;
    });
    unawaited(HapticFeedback.selectionClick());

    try {
      final payLink = await resolve(raw);
      if (!mounted) {
        controller.releaseGift();
        _holding = false;
        return;
      }
      setState(() => _phase = _NfcPhase.paying);
      _payoutStarted = true;
      await payer.payWithdrawTo(
        withdrawLnurl: gift.lnurl!,
        payLink: payLink,
        sats: gift.satsAmount,
      );
      controller.completeTreasureClaim(gift);
      controller.recordClaim(
        ClaimedGift(gift: gift, claimedAt: DateTime.now()),
      );
      _holding = false;
      _payoutStarted = false;
      if (!mounted) return;
      unawaited(HapticFeedback.mediumImpact());
      setState(() => _phase = _NfcPhase.success);
      _resume?.cancel();
      _resume = Timer(const Duration(milliseconds: 2400), () {
        if (!mounted) return;
        setState(() => _phase = _NfcPhase.idle);
        if (!_ios) unawaited(_listen());
      });
    } on AppException catch (error) {
      controller.releaseGift();
      _holding = false;
      _payoutStarted = false;
      _showError(error.message);
    } catch (_) {
      controller.releaseGift();
      _holding = false;
      _payoutStarted = false;
      _showError('No se pudo cobrar el premio');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _phase = _NfcPhase.error;
      _message = message;
    });
  }

  void _retry() {
    _resume?.cancel();
    setState(() {
      _phase = _NfcPhase.idle;
      _message = null;
    });
    if (_availability != NfcAvailability.enabled) {
      unawaited(_arm());
      return;
    }
    unawaited(_listen());
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(ticketFlowProvider, (previous, next) {
      final freed =
          previous?.claimingGiftId != null && next.claimingGiftId == null;
      if (freed && _phase == _NfcPhase.idle && !_ios) unawaited(_listen());
    });

    final state = ref.watch(ticketFlowProvider);
    final claimable = [
      for (final gift in state.visibleBenefits)
        if (gift.isTreasure && gift.canPrint) gift,
    ];
    final busy =
        _phase == _NfcPhase.reading ||
        _phase == _NfcPhase.paying ||
        _phase == _NfcPhase.success ||
        _phase == _NfcPhase.error;

    if (!_mobile || !_ready) return const SizedBox.shrink();
    if (_availability == NfcAvailability.unsupported) {
      return const SizedBox.shrink();
    }
    if (claimable.isEmpty && !busy) return const SizedBox.shrink();

    final next = claimable.isEmpty ? null : claimable.first;
    final sats = _phase == _NfcPhase.idle ? next?.satsAmount : _sats;
    final label = _phase == _NfcPhase.idle ? next?.label : _label;
    final waiting = claimable.length > 1 ? claimable.length - 1 : 0;

    final card = _NfcCard(
      phase: _phase,
      sats: sats,
      label: label,
      waiting: waiting,
      message: _message,
      ios: _ios,
      onRetry: _retry,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: LcSpace.lg),
      child: _ios && _phase == _NfcPhase.idle
          ? LcPressable(
              onTap: () => unawaited(_listen()),
              semanticLabel: 'Leer tarjeta para cobrar sats',
              child: card,
            )
          : card,
    );
  }
}

class _NfcCard extends StatelessWidget {
  const _NfcCard({
    required this.phase,
    required this.sats,
    required this.label,
    required this.waiting,
    required this.message,
    required this.ios,
    required this.onRetry,
  });

  final _NfcPhase phase;
  final int? sats;
  final String? label;
  final int waiting;
  final String? message;
  final bool ios;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final live = phase == _NfcPhase.idle || phase == _NfcPhase.success;
    final color = switch (phase) {
      _NfcPhase.error || _NfcPhase.off => LcColors.amber,
      _ => LcColors.accent,
    };

    return AnimatedContainer(
      duration: LcMotion.normal,
      curve: LcMotion.brand,
      padding: const EdgeInsets.all(LcSpace.md),
      decoration: BoxDecoration(
        color: LcColors.card,
        borderRadius: LcRadius.cardAll,
        border: Border.all(color: color.withValues(alpha: live ? 0.46 : 0.28)),
      ),
      child: Row(
        children: [
          _NfcHalo(phase: phase),
          const SizedBox(width: LcSpace.md),
          Expanded(child: _copy(color)),
        ],
      ),
    );
  }

  Widget _copy(Color color) {
    final title = switch (phase) {
      _NfcPhase.reading => 'Leyendo tarjeta',
      _NfcPhase.paying => 'Acreditando',
      _NfcPhase.success => 'Premio acreditado',
      _NfcPhase.error => 'No se pudo cobrar',
      _NfcPhase.off => 'NFC apagado',
      _NfcPhase.idle => ios ? 'Tocá para leer' : 'Apoyá la tarjeta',
    };
    final detail = switch (phase) {
      _NfcPhase.error => message ?? 'Probá de nuevo',
      _NfcPhase.off => 'Activalo para cobrar el premio',
      _NfcPhase.success => _prizeLine(),
      _NfcPhase.paying => _prizeLine(),
      _NfcPhase.reading => 'Buscando el link de cobro',
      _NfcPhase.idle => _prizeLine(),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LcEyebrow(
          phase == _NfcPhase.idle ? 'cobrar con tarjeta' : 'nfc',
          color: color,
        ),
        const SizedBox(height: 4),
        AnimatedSwitcher(
          duration: LcMotion.normal,
          switchInCurve: LcMotion.brand,
          child: Text(title, key: ValueKey(title), style: LcType.h3),
        ),
        const SizedBox(height: 4),
        Text(detail, style: LcType.caption),
        if (phase == _NfcPhase.idle && waiting > 0) ...[
          const SizedBox(height: 6),
          Text(
            waiting == 1
                ? 'Después queda 1 premio'
                : 'Después quedan $waiting premios',
            style: LcType.caption,
          ),
        ],
        if (phase == _NfcPhase.error || phase == _NfcPhase.off) ...[
          const SizedBox(height: LcSpace.sm),
          LcPressable(
            onTap: onRetry,
            semanticLabel: 'Reintentar lectura NFC',
            child: Text(
              'Reintentar',
              style: LcType.buttonSmall.copyWith(color: color),
            ),
          ),
        ],
      ],
    );
  }

  String _prizeLine() {
    final amount = sats;
    final name = label;
    if (amount != null && amount > 0 && name != null && name.isNotEmpty) {
      return '${_sats(amount)} sats · $name';
    }
    if (amount != null && amount > 0) return '${_sats(amount)} sats';
    if (name != null && name.isNotEmpty) return name;
    return 'Premio en sats';
  }
}

String _sats(int amount) => NumberFormat.decimalPattern('es_AR').format(amount);

class _NfcHalo extends StatefulWidget {
  const _NfcHalo({required this.phase});

  final _NfcPhase phase;

  @override
  State<_NfcHalo> createState() => _NfcHaloState();
}

class _NfcHaloState extends State<_NfcHalo> with TickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: LcMotion.nfcPulse,
  )..repeat();

  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: LcMotion.slow,
  );

  @override
  void didUpdateWidget(_NfcHalo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.phase == _NfcPhase.success &&
        oldWidget.phase != _NfcPhase.success) {
      _burst.forward(from: 0);
    }
    if (widget.phase == _NfcPhase.idle && !_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _burst.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listening = widget.phase == _NfcPhase.idle;
    final success = widget.phase == _NfcPhase.success;
    final failed =
        widget.phase == _NfcPhase.error || widget.phase == _NfcPhase.off;
    final color = failed ? LcColors.amber : LcColors.accent;

    return SizedBox(
      width: 88,
      height: 88,
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulse, _burst]),
        builder: (context, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              if (listening)
                for (var i = 0; i < 3; i++)
                  _Ring(t: (_pulse.value + i / 3) % 1, color: color),
              if (success) _Ring(t: _burst.value, color: color, strong: true),
              AnimatedScale(
                scale: success ? 0.92 + (_burst.value.clamp(0, 1) * 0.08) : 1,
                duration: LcMotion.normal,
                curve: LcMotion.brand,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.12),
                    border: Border.all(color: color.withValues(alpha: 0.5)),
                    boxShadow: listening || success
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.22),
                              blurRadius: 18,
                            ),
                          ]
                        : null,
                  ),
                  child: Center(child: _icon(color)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _icon(Color color) {
    return switch (widget.phase) {
      _NfcPhase.reading ||
      _NfcPhase.paying => LcSpinner(size: 28, color: color),
      _NfcPhase.success => Icon(
        LucideIcons.circleCheck,
        size: 30,
        color: color,
      ),
      _NfcPhase.error ||
      _NfcPhase.off => Icon(LucideIcons.triangleAlert, size: 28, color: color),
      _NfcPhase.idle => Icon(LucideIcons.nfc, size: 30, color: color),
    };
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.t, required this.color, this.strong = false});

  final double t;
  final Color color;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final scale = 0.72 + (strong ? 0.9 : 0.7) * t;
    final opacity = (1 - t) * (strong ? 0.7 : 0.45);
    return Transform.scale(
      scale: scale,
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: color.withValues(alpha: opacity.clamp(0, 1)),
            width: strong ? 2 : 1.5,
          ),
        ),
      ),
    );
  }
}
