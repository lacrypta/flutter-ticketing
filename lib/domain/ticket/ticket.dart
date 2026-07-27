import '../../data/api/ticketing_dto.dart';

/// One entrada, as the door sees it.
///
/// Check-in is **per ticket, not per attendee**: a buyer with four entradas can
/// be scanned four times, and each scan claims exactly the item its own code
/// maps to. [ticketsTotal] / [ticketsClaimed] exist so the operator can see
/// that at a glance ("Entrada 2 de 4") instead of wondering why a name they
/// already checked in is valid again.
class Ticket {
  const Ticket({
    required this.token,
    required this.attendeeName,
    required this.eventName,
    required this.checkedIn,
    required this.checkedInAt,
    required this.staffRequired,
    this.ticketNumber,
    this.ticketsTotal,
    this.ticketsAvailable,
    this.ticketsClaimed,
  });

  factory Ticket.fromStatus(String token, CheckinStatusDto dto) => Ticket(
    token: token,
    attendeeName: dto.attendeeName,
    eventName: dto.eventName,
    checkedIn: dto.checkedIn,
    checkedInAt: dto.checkedInAt,
    staffRequired: dto.staffRequired,
    ticketsTotal: dto.ticketsTotal,
    ticketsAvailable: dto.ticketsAvailable,
    ticketsClaimed: dto.ticketsClaimed,
  );

  final String token;
  final String attendeeName;
  final String eventName;
  final bool checkedIn;
  final DateTime? checkedInAt;
  final bool staffRequired;
  final int? ticketNumber;
  final int? ticketsTotal;
  final int? ticketsAvailable;
  final int? ticketsClaimed;

  bool get hasInventory => (ticketsTotal ?? 0) > 1;

  Ticket applyCheckin(CheckinResultDto result) => Ticket(
    token: token,
    attendeeName: result.attendeeName.isNotEmpty
        ? result.attendeeName
        : attendeeName,
    eventName: eventName,
    checkedIn: true,
    checkedInAt: result.checkedInAt ?? checkedInAt ?? DateTime.now(),
    staffRequired: staffRequired,
    ticketNumber: result.ticketNumber ?? ticketNumber,
    ticketsTotal: result.ticketsTotal ?? ticketsTotal,
    ticketsAvailable: result.ticketsAvailable ?? ticketsAvailable,
    ticketsClaimed: result.ticketsClaimed ?? ticketsClaimed,
  );
}

/// A row in the local scan history.
class ScanRecord {
  const ScanRecord({
    required this.token,
    required this.scannedAt,
    required this.status,
    this.attendeeName,
    this.eventName,
  });

  final String token;
  final DateTime scannedAt;
  final ScanStatus status;
  final String? attendeeName;
  final String? eventName;

  bool get succeeded =>
      status == ScanStatus.checkedIn || status == ScanStatus.alreadyCheckedIn;
}

enum ScanStatus {
  checkedIn,
  alreadyCheckedIn,
  invalid,
  staffRequired,
  eventEnded,
  pending,
}
