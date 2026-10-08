import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lacrypta_ticketing/core/error/app_exception.dart';
import 'package:lacrypta_ticketing/data/api/api_providers.dart';
import 'package:lacrypta_ticketing/data/api/ticketing_api.dart';
import 'package:lacrypta_ticketing/data/api/ticketing_dto.dart';
import 'package:lacrypta_ticketing/domain/ticket/gift.dart';
import 'package:lacrypta_ticketing/features/ticket/ticket_controller.dart';
import 'package:mocktail/mocktail.dart';

class _MockApi extends Mock implements TicketingApi {}

CheckinStatusDto _status({bool checkedIn = false}) =>
    CheckinStatusDto.fromJson({
      'attendee_name': 'Satoshi Pipeline',
      'event_name': 'Flutter Pipeline Test',
      'checked_in': checkedIn,
      'checked_in_at': null,
      'staff_required': false,
    });

CheckinResultDto get _checkedIn => CheckinResultDto.fromJson({
  'status': 'checked_in',
  'attendee_name': 'Satoshi Pipeline',
  'checked_in_at': '2026-07-29T17:00:00.000Z',
});

void main() {
  late _MockApi api;
  late ProviderContainer container;

  setUp(() {
    api = _MockApi();
    container = ProviderContainer(
      overrides: [ticketingApiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
  });

  TicketFlowController controller() =>
      container.read(ticketFlowProvider.notifier);
  TicketFlowState state() => container.read(ticketFlowProvider);

  group('loadBenefits — a 404 from /gifts is not a bad ticket', () {
    // Verified against a live lacrypta-crm: GET /api/checkin/{code}/gifts 404s
    // for a code that GET /api/checkin/{code} resolves perfectly well, because
    // loadCheckinTicket queries only orders.ticket_code and its `events` embed
    // is missing the FK disambiguation hint. Until that is fixed server-side,
    // a 404 here must read as "no benefits", never as "Ticket inválido" —
    // otherwise the operator sees an error stacked under a check-in that
    // just succeeded.
    test('lands on the gifts phase with no error and no gifts', () async {
      when(() => api.status(any())).thenAnswer((_) async => _status());
      when(() => api.checkin(any())).thenAnswer((_) async => _checkedIn);
      when(() => api.gifts(any())).thenThrow(const InvalidTicketException());

      await controller().open('2fa5da54-3de0-431d-a48d-952a4588673f');
      await controller().checkin();

      expect(state().phase, TicketPhase.gifts);
      expect(state().error, isNull, reason: 'a 404 here is not an error');
      expect(state().gifts, isEmpty);
      expect(state().giftUnits, isEmpty);
      expect(
        state().ticket?.checkedIn,
        isTrue,
        reason: 'the check-in itself still succeeded',
      );
    });

    test('a real failure is still surfaced', () async {
      when(() => api.status(any())).thenAnswer((_) async => _status());
      when(() => api.gifts(any())).thenThrow(const NetworkException());

      await controller().open('token');
      await controller().loadBenefits();

      expect(state().phase, TicketPhase.gifts);
      expect(state().error, isNotNull);
    });

    test('a 500 is still surfaced', () async {
      when(() => api.status(any())).thenAnswer((_) async => _status());
      when(() => api.gifts(any())).thenThrow(
        const ApiException(status: 500, message: 'No se pudieron cargar'),
      );

      await controller().open('token');
      await controller().loadBenefits();

      expect(state().error, 'No se pudieron cargar');
    });
  });

  group('a printed treasure stays claimable', () {
    const lnurl =
        'lnurl1dp68gurn8ghj7mrww4exctt5dahkccn00qhxget8wfjkxmmww3jhxaq0v3jk6mnyv4ej7mrww4exctn9v4jk6mnyv4ej7mr0va5kuer';
    final treasure = {
      'item_key': 'treasure_chest',
      'claim_code': '0024f7c1-4b87-41f9-939f-f7f96ff022a2',
      'quantity': 1,
      'kind': 'sats_treasure',
      'name': 'Treasure chest',
      'sats_amount': 210,
      'lnurl': lnurl,
    };

    Future<void> load() async {
      when(
        () => api.status(any()),
      ).thenAnswer((_) async => _status(checkedIn: true));
      when(() => api.gifts(any())).thenAnswer(
        (_) async =>
            CheckinGiftsDto(counts: <String, int>{}, catalogue: [treasure]),
      );
      await controller().open('token');
      await controller().loadBenefits();
    }

    test('printing removes it locally and never consumes it', () async {
      await load();
      final gift = state().giftUnits.single;

      final printed = await controller().claimGift(gift);

      expect(printed?.lnurl, lnurl);
      expect(state().giftUnits, isEmpty);
      verifyNever(() => api.consumeGift(any(), any()));
      controller().recordClaim(
        ClaimedGift(gift: printed!, claimedAt: DateTime.utc(2026, 10, 2, 17)),
      );
      expect(state().claimed.single.gift.id, gift.id);
    });

    test(
      'the next check-in reprints the same LUD-03 while it is still ready',
      () async {
        await load();
        final gift = state().giftUnits.single;
        await controller().claimGift(gift);

        await load();

        final again = state().giftUnits.single;
        expect(again.id, gift.id);
        expect(again.lnurl, lnurl);
        expect(state().claimed, isEmpty);
      },
    );

    test(
      'the door opens on the ticket and can switch to the user list',
      () async {
        final ticketGift = {
          'kind': 'gift',
          'item_key': 'tarjeta_lawallet',
          'name': 'Tarjeta LaWallet',
          'quantity_label': '×1',
          'status_label': 'Reclamado',
          'claimed': true,
          'printable': false,
        };
        final ticketChest = {
          'kind': 'sats_treasure',
          'item_key': 'treasure_chest',
          'claim_code': '0024f7c1-4b87-41f9-939f-f7f96ff022a2',
          'name': 'Treasure chest',
          'sats_amount': 210,
          'quantity_label': '210 sats',
          'status_label': 'Disponible',
          'claimed': false,
          'printable': true,
          'lnurl': lnurl,
        };
        final otherChest = {
          ...ticketChest,
          'claim_code': 'ebf2aade-2da4-4b10-bea5-d08875530840',
          'sats_amount': 100,
          'quantity_label': '100 sats',
        };
        when(
          () => api.status(any()),
        ).thenAnswer((_) async => _status(checkedIn: true));
        when(() => api.gifts(any())).thenAnswer(
          (_) async => CheckinGiftsDto.fromJson({
            'gift_data': <String, dynamic>{},
            'gifts': <Map<String, dynamic>>[],
            'ticket_benefits': [ticketGift, ticketChest],
            'user_benefits': [ticketGift, ticketChest, otherChest],
          }),
        );

        await controller().open('token');
        await controller().loadBenefits();

        expect(state().showUserGifts, isFalse);
        expect(state().visibleBenefits.map((gift) => gift.id), [
          'tarjeta_lawallet',
          '0024f7c1-4b87-41f9-939f-f7f96ff022a2',
        ]);
        expect(state().visibleBenefits.first.canPrint, isFalse);

        controller().toggleGiftScope();

        expect(state().showUserGifts, isTrue);
        expect(state().visibleBenefits, hasLength(3));

        controller().toggleGiftScope();
        expect(state().showUserGifts, isFalse);

        final printed = await controller().claimGift(
          state().visibleBenefits[1],
        );
        expect(printed?.id, '0024f7c1-4b87-41f9-939f-f7f96ff022a2');
        expect(state().ticketBenefits[1].printedLocally, isTrue);
        expect(state().userBenefits[1].printedLocally, isTrue);
        expect(
          identical(state().ticketBenefits[1], state().userBenefits[1]),
          isTrue,
        );

        controller().toggleGiftScope();
        expect(state().visibleBenefits[1].canPrint, isFalse);
        expect(state().visibleBenefits[1].statusLabel, 'Impreso');
      },
    );

    test(
      'a card payout claims the chest and does not consume a quantity',
      () async {
        await load();
        final gift = state().giftUnits.single;

        expect(controller().holdGift(gift.id), isTrue);
        expect(controller().holdGift('other'), isFalse);
        controller().completeTreasureClaim(gift);
        controller().recordClaim(
          ClaimedGift(gift: gift, claimedAt: DateTime.utc(2026, 10, 8, 15)),
        );

        expect(state().claimingGiftId, isNull);
        expect(state().giftUnits, isEmpty);
        expect(state().claimed.single.gift.id, gift.id);
        verifyNever(() => api.consumeGift(any(), any()));
      },
    );

    test('a card that cannot pay leaves the chest available', () async {
      await load();
      final gift = state().giftUnits.single;

      controller().holdGift(gift.id);
      controller().releaseGift(error: 'La tarjeta no tiene un link de cobro');

      expect(state().claimingGiftId, isNull);
      expect(state().error, 'La tarjeta no tiene un link de cobro');
      expect(state().giftUnits.single.lnurl, lnurl);
      expect(state().giftUnits.single.canPrint, isTrue);
    });

    test('a treasure the wallet already claimed does not come back', () async {
      await load();
      await controller().claimGift(state().giftUnits.single);
      when(() => api.gifts(any())).thenAnswer(
        (_) async => const CheckinGiftsDto(
          counts: <String, int>{},
          catalogue: <Map<String, dynamic>>[],
        ),
      );

      await controller().open('token');
      await controller().loadBenefits();

      expect(state().giftUnits, isEmpty);
    });
  });

  group('open', () {
    test('an already-claimed ticket goes straight to alreadyChecked', () async {
      when(
        () => api.status(any()),
      ).thenAnswer((_) async => _status(checkedIn: true));

      await controller().open('token');

      expect(state().phase, TicketPhase.alreadyChecked);
    });

    test('staff_required gets its own phase, not "invalid"', () async {
      when(() => api.status(any())).thenThrow(const StaffRequiredException());

      await controller().open('token');

      expect(state().phase, TicketPhase.staffRequired);
    });

    test('event_ended gets its own phase', () async {
      when(() => api.status(any())).thenThrow(const EventEndedException());

      await controller().open('token');

      expect(state().phase, TicketPhase.eventEnded);
    });

    test('an unknown token is invalid', () async {
      when(() => api.status(any())).thenThrow(const InvalidTicketException());

      await controller().open('nope');

      expect(state().phase, TicketPhase.invalid);
    });
  });
}
