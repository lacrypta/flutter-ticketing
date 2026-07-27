/// Wire types for the ticketing API.
///
/// Field names and nullability were taken from the route handlers themselves
/// (`lacrypta-crm/app/api/checkin/[code]/**`), not inferred from the web app —
/// which reads only five of the nine fields `GET` actually returns.
library;

/// `GET /api/checkin/{code}`
class CheckinStatusDto {
  const CheckinStatusDto({
    required this.attendeeName,
    required this.eventName,
    required this.checkedIn,
    required this.checkedInAt,
    required this.staffRequired,
    this.ticketsTotal,
    this.ticketsAvailable,
    this.ticketsClaimed,
  });

  factory CheckinStatusDto.fromJson(Map<String, dynamic> json) =>
      CheckinStatusDto(
        attendeeName: json['attendee_name'] as String? ?? '',
        eventName: json['event_name'] as String? ?? '',
        checkedIn: json['checked_in'] as bool? ?? false,
        checkedInAt: _parseDate(json['checked_in_at']),
        staffRequired: json['staff_required'] as bool? ?? false,
        ticketsTotal: json['tickets_total'] as int?,
        ticketsAvailable: json['tickets_available'] as int?,
        ticketsClaimed: json['tickets_claimed'] as int?,
      );

  final String attendeeName;
  final String eventName;
  final bool checkedIn;
  final DateTime? checkedInAt;

  /// When true, `POST` requires a manager-level identity. The web app reads
  /// this field and then ignores it.
  final bool staffRequired;

  /// Inventory across the buyer's entradas for this event. Check-in is
  /// per-ticket, so a buyer with four entradas can be scanned four times.
  final int? ticketsTotal;
  final int? ticketsAvailable;
  final int? ticketsClaimed;
}

/// `POST /api/checkin/{code}`
class CheckinResultDto {
  const CheckinResultDto({
    required this.alreadyCheckedIn,
    required this.attendeeName,
    required this.checkedInAt,
    this.ticketNumber,
    this.ticketsTotal,
    this.ticketsAvailable,
    this.ticketsClaimed,
  });

  factory CheckinResultDto.fromJson(Map<String, dynamic> json) =>
      CheckinResultDto(
        alreadyCheckedIn: json['status'] == 'already_checked_in',
        attendeeName: json['attendee_name'] as String? ?? '',
        checkedInAt: _parseDate(json['checked_in_at']),
        ticketNumber: json['ticket_number'] as int?,
        ticketsTotal: json['tickets_total'] as int?,
        ticketsAvailable: json['tickets_available'] as int?,
        ticketsClaimed: json['tickets_claimed'] as int?,
      );

  /// `status` is `checked_in` or `already_checked_in`. The second is not an
  /// error — POST is idempotent, which is what makes offline replay safe.
  final bool alreadyCheckedIn;

  final String attendeeName;
  final DateTime? checkedInAt;

  /// Which entrada of the buyer's set this was ("Entrada 2 de 4").
  final int? ticketNumber;

  final int? ticketsTotal;
  final int? ticketsAvailable;
  final int? ticketsClaimed;
}

/// `GET .../gifts` and `POST .../gifts/consume` both return `gift_data`:
/// a map of `item_key` → **remaining** quantity after the operation.
typedef GiftData = Map<String, int>;

GiftData parseGiftData(Object? raw) {
  if (raw is! Map) return <String, int>{};
  final result = <String, int>{};
  raw.forEach((key, value) {
    final quantity = value is num ? value.toInt() : int.tryParse('$value');
    if (quantity != null && quantity > 0) result['$key'] = quantity;
  });
  return result;
}

DateTime? _parseDate(Object? raw) =>
    raw is String ? DateTime.tryParse(raw)?.toLocal() : null;
