import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    this.catalogue = const {},
    this.benefitById = const {},
    this.ticketBenefitIds = const [],
    this.userBenefitIds = const [],
    this.scoped = false,
    this.showUserGifts = false,
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

  /// `item_key` → title/artwork, straight from the server.
  final Map<String, Gift> catalogue;

  /// One record per benefit. Both tabs read this, so a claim updates both.
  final Map<String, Gift> benefitById;

  final List<String> ticketBenefitIds;
  final List<String> userBenefitIds;

  /// The server sent [ticketBenefits] / [userBenefits].
  final bool scoped;

  /// False shows the ticket. The next scan always starts there.
  final bool showUserGifts;

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
      for (var i = 0; i < entry.value; i++)
        catalogue[entry.key] ?? Gift(id: entry.key, label: entry.key),
  ];

  List<Gift> get ticketBenefits => _giftsFor(ticketBenefitIds);

  List<Gift> get userBenefits => _giftsFor(userBenefitIds);

  List<Gift> get visibleBenefits {
    if (!scoped) return giftUnits;
    return showUserGifts ? userBenefits : ticketBenefits;
  }

  List<Gift> _giftsFor(List<String> ids) => [
    for (final id in ids)
      if (benefitById[id] != null) benefitById[id]!,
  ];

  TicketFlowState copyWith({
    TicketPhase? phase,
    String? token,
    Ticket? ticket,
    Map<String, int>? gifts,
    Map<String, Gift>? catalogue,
    Map<String, Gift>? benefitById,
    List<String>? ticketBenefitIds,
    List<String>? userBenefitIds,
    bool? scoped,
    bool? showUserGifts,
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
    catalogue: catalogue ?? this.catalogue,
    benefitById: benefitById ?? this.benefitById,
    ticketBenefitIds: ticketBenefitIds ?? this.ticketBenefitIds,
    userBenefitIds: userBenefitIds ?? this.userBenefitIds,
    scoped: scoped ?? this.scoped,
    showUserGifts: showUserGifts ?? this.showUserGifts,
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
      final result = await request;
      await floor;
      final catalogue = <String, Gift>{};
      final counts = Map<String, int>.from(result.counts);
      for (final json in result.catalogue) {
        if (json['item_key'] == null) continue;
        final gift = Gift.fromJson(json);
        catalogue[gift.id] = gift;
        if (!gift.isTreasure) continue;
        // A treasure is one chest, not a quantity of the shared item key.
        counts.remove(json['item_key'].toString());
        counts[gift.id] = 1;
      }
      final ticketList = result.ticketBenefits ?? const <Gift>[];
      final userList = result.userBenefits ?? const <Gift>[];
      state = state.copyWith(
        gifts: counts,
        catalogue: catalogue,
        scoped: result.scoped,
        benefitById: {
          for (final gift in userList) gift.id: gift,
          for (final gift in ticketList) gift.id: gift,
        },
        ticketBenefitIds: [for (final gift in ticketList) gift.id],
        userBenefitIds: [for (final gift in userList) gift.id],
        phase: TicketPhase.gifts,
      );
    } on InvalidTicketException {
      // A 404 here does NOT mean the ticket is bad — we only got this far
      // because it validated and checked in seconds ago. The gifts endpoint
      // resolves codes differently from the check-in endpoint and 404s for
      // codes that are perfectly valid (see README → Backend asks), so
      // surfacing "Ticket inválido" under a successful check-in would be both
      // wrong and alarming. Treat it as "this attendee has no benefits".
      state = state.copyWith(
        gifts: const {},
        phase: TicketPhase.gifts,
        clearError: true,
      );
    } on AppException catch (error) {
      // Everything else stays loud: a network drop or a 500 is real.
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
      if (gift.isTreasure) {
        // Printing the LUD-03 is the handoff. The wallet still withdraws later,
        // so this must not burn the chest on the gift-quantity endpoint.
        // The row reads as printed for this session and comes back, still
        // READY, the next time the ticket is opened.
        final remaining = Map<String, int>.from(state.gifts)..remove(gift.id);
        state = state.copyWith(
          gifts: remaining,
          benefitById: _markPrinted(state.benefitById, gift),
          clearClaiming: true,
        );
        return gift;
      }
      final remaining = await ref
          .read(ticketingApiProvider)
          .consumeGift(ticket.token, gift.id);
      state = state.copyWith(
        gifts: remaining,
        benefitById: _markPrinted(state.benefitById, gift),
        clearClaiming: true,
      );
      return gift;
    } on AppException catch (error) {
      state = state.copyWith(clearClaiming: true, error: error.message);
      return null;
    }
  }

  void selectGiftScope(bool user) {
    if (state.showUserGifts == user) return;
    state = state.copyWith(showUserGifts: user);
  }

  void toggleGiftScope() => selectGiftScope(!state.showUserGifts);

  static Map<String, Gift> _markPrinted(Map<String, Gift> gifts, Gift gift) {
    final current = gifts[gift.id] ?? gift;
    return {
      ...gifts,
      gift.id: current.copyWith(
        printedLocally: true,
        claimed: current.isTreasure ? current.claimed : true,
        statusLabel: current.isTreasure ? 'Impreso' : 'Reclamado',
      ),
    };
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
