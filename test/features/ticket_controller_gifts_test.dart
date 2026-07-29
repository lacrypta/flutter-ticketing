import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lacrypta_ticketing/core/error/app_exception.dart';
import 'package:lacrypta_ticketing/data/api/api_providers.dart';
import 'package:lacrypta_ticketing/data/api/ticketing_api.dart';
import 'package:lacrypta_ticketing/data/api/ticketing_dto.dart';
import 'package:lacrypta_ticketing/features/ticket/ticket_controller.dart';
import 'package:mocktail/mocktail.dart';

class _MockApi extends Mock implements TicketingApi {}

CheckinStatusDto _status({bool checkedIn = false}) => CheckinStatusDto.fromJson({
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
      when(
        () => api.gifts(any()),
      ).thenThrow(const InvalidTicketException());

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
