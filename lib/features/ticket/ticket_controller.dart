import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/gift_catalogue.dart';
import '../../core/error/app_exception.dart';
import '../../core/theme/lc_metrics.dart';
import '../../data/api/api_providers.dart';
import '../../domain/ticket/gift.dart';
import '../../domain/ticket/ticket.dart';

/// Where the operator is in the scan → check-in → benefits flow.
///
/// Mirrors the web app's screen state machine, plus three terminal states it
/// does not have: [staffRequired] and [eventEnded] (both real API responses the
/// web app collapses into a generic error) and an explicit [invalid].
enum TicketPhase {
  idle,
  validating,
  invalid,
  staffRequired,
  eventEnded,
  checkin,
  alreadyChecked,
  benefits,
  gifts,
}

class TicketFlowState {
  const TicketFlowState({
    this.phase = TicketPhase.idle,
    this.token,
    this.ticket,
    this.gifts = const {},
    this.claimed = const [],
    this.error,
    this.busy = false,
    this.claimingGiftId,
  });

  final TicketPhase phase;
  final String? token;
  final Ticket? ticket;

  /// `item_key` → remaining. Replaced wholesale by each server response.
  final Map<String, int> gifts;

  final List<ClaimedGift> claimed;
  final String? error;

  /// A check-in is in flight. Blocks the CTA so a double-tap cannot fire twice.
  final bool busy;

  /// Which gift row is currently being consumed/printed.
  final String? claimingGiftId;

  /// The gift list is expanded to **one entry per unit**: a remaining count of
  /// three renders three rows, so claiming is always a single tap and never a
  /// quantity picker. Ported from the web app.
  List<Gift> get giftUnits => [
    for (final entry in gifts.entries)
      for (var i = 0; i < entry.value; i++) resolveGift(entry.key),
  ];

  TicketFlowState copyWith({
    TicketPhase? phase,
    String? token,
    Ticket? ticket,
    Map<String, int>? gifts,
    List<ClaimedGift>? claimed,
    String? error,
    bool? busy,
    String? claimingGiftId,
    bool clearError = false,
    bool clearClaiming = false,
  }) => TicketFlowState(
    phase: phase ?? this.phase,
    token: token ?? this.token,
    ticket: ticket ?? this.ticket,
    gifts: gifts ?? this.gifts,
    claimed: claimed ?? this.claimed,
    error: clearError ? null : (error ?? this.error),
    busy: busy ?? this.busy,
    claimingGiftId: clearClaiming
        ? null
        : (claimingGiftId ?? this.claimingGiftId),
  );
}

class TicketFlowController extends Notifier<TicketFlowState> {
  @override
  TicketFlowState build() => const TicketFlowState();

  /// Entry point for both a scanned QR and an NFC card resolution.
  Future<void> open(String token) async {
    state = TicketFlowState(phase: TicketPhase.validating, token: token);
    try {
      final dto = await ref.read(ticketingApiProvider).status(token);
      final ticket = Ticket.fromStatus(token, dto);
      state = state.copyWith(
        ticket: ticket,
        phase: ticket.checkedIn
            ? TicketPhase.alreadyChecked
            : TicketPhase.checkin,
      );
    } on AppException catch (error) {
      state = state.copyWith(phase: _phaseFor(error), error: error.message);
    }
  }

  Future<void> checkin() async {
    final ticket = state.ticket;
    if (ticket == null || state.busy) return;

    state = state.copyWith(busy: true, clearError: true);
    try {
      final result = await ref.read(ticketingApiProvider).checkin(ticket.token);
      state = state.copyWith(ticket: ticket.applyCheckin(result), busy: false);
      await loadBenefits();
    } on AppException catch (error) {
      state = state.copyWith(
        busy: false,
        phase: error is StaffRequiredException || error is EventEndedException
            ? _phaseFor(error)
            : state.phase,
        error: error.message,
      );
    }
  }

  Future<void> loadBenefits() async {
    final ticket = state.ticket;
    if (ticket == null) return;

    state = state.copyWith(phase: TicketPhase.benefits, clearError: true);
    try {
      // Both started before either is awaited, so the delay runs concurrently
      // with the request rather than after it. The floor exists so a fast
      // response does not flash a spinner for 40ms, which reads as a glitch
      // rather than as work. Ported from the web app.
      final request = ref.read(ticketingApiProvider).gifts(ticket.token);
      final floor = Future<void>.delayed(LcMotion.minimumLoad);
      final gifts = await request;
      await floor;
      state = state.copyWith(gifts: gifts, phase: TicketPhase.gifts);
    } on AppException catch (error) {
      state = state.copyWith(phase: TicketPhase.gifts, error: error.message);
    }
  }

  /// Consumes one unit of [gift].
  ///
  /// Note the ordering: the server call completes **before** anything is
  /// printed. Printing first would be faster but a `409 insufficient_gift`
  /// after a receipt has come out of the printer is a discrepancy nobody at the
  /// door can resolve.
  Future<Gift?> claimGift(Gift gift) async {
    final ticket = state.ticket;
    if (ticket == null || state.claimingGiftId != null) return null;

    state = state.copyWith(claimingGiftId: gift.id, clearError: true);
    try {
      final remaining = await ref
          .read(ticketingApiProvider)
          .consumeGift(ticket.token, gift.id);
      state = state.copyWith(gifts: remaining, clearClaiming: true);
      return gift;
    } on AppException catch (error) {
      state = state.copyWith(clearClaiming: true, error: error.message);
      return null;
    }
  }

  /// Records a successful claim once its receipt has been dealt with.
  void recordClaim(ClaimedGift claim) {
    state = state.copyWith(claimed: [claim, ...state.claimed]);
  }

  void reset() => state = const TicketFlowState();

  /// Back navigation, mirroring the web app's `handleBack`.
  void back() {
    switch (state.phase) {
      case TicketPhase.gifts:
      case TicketPhase.benefits:
        state = state.copyWith(
          phase: (state.ticket?.checkedIn ?? false)
              ? TicketPhase.alreadyChecked
              : TicketPhase.checkin,
          clearError: true,
        );
      case TicketPhase.idle:
      case TicketPhase.validating:
      case TicketPhase.invalid:
      case TicketPhase.staffRequired:
      case TicketPhase.eventEnded:
      case TicketPhase.checkin:
      case TicketPhase.alreadyChecked:
        reset();
    }
  }

  static TicketPhase _phaseFor(AppException error) => switch (error) {
    StaffRequiredException() => TicketPhase.staffRequired,
    EventEndedException() => TicketPhase.eventEnded,
    _ => TicketPhase.invalid,
  };
}

final ticketFlowProvider =
    NotifierProvider<TicketFlowController, TicketFlowState>(
      TicketFlowController.new,
    );
