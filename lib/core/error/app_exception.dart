/// The app's error vocabulary.
///
/// Every one of these maps to a distinct thing the operator has to *do* at the
/// door, which is why they are separate types rather than one exception with a
/// status code. The web app collapses all of them into a single "ticket
/// inválido" screen; several are not invalid tickets at all.
sealed class AppException implements Exception {
  const AppException(this.message);

  /// Shown to the operator, in Spanish.
  final String message;

  @override
  String toString() => message;
}

/// No usable connection. Retryable, and the trigger for queueing offline.
class NetworkException extends AppException {
  const NetworkException([super.message = 'Sin conexión']);
}

/// The token does not resolve to a ticket (HTTP 404).
class InvalidTicketException extends AppException {
  const InvalidTicketException([super.message = 'Ticket inválido']);
}

/// The event has `staff_checkin_required = true` and we are not authenticated
/// as a manager (HTTP 401/403, `{"error":"staff_required"}`).
///
/// This is **not** a bad ticket — the attendee is fine and a staff member with
/// a logged-in device can let them in. Surfacing it as "invalid" would turn
/// people away at the door for a configuration reason.
class StaffRequiredException extends AppException {
  const StaffRequiredException([
    super.message = 'Este evento requiere check-in de staff',
  ]);
}

/// The event is over, so the ticket has expired (HTTP 409, `event_ended`).
class EventEndedException extends AppException {
  const EventEndedException([super.message = 'El evento ya terminó']);
}

/// Stock ran out between listing and consuming (HTTP 409, `insufficient_gift`).
///
/// The important case for the offline queue: a consume that was accepted
/// locally can still fail here on replay, after a receipt has already printed.
class InsufficientGiftException extends AppException {
  const InsufficientGiftException([
    super.message = 'No quedan unidades de este beneficio',
  ]);
}

/// Any other non-2xx. [status] and [error] are preserved for diagnostics.
class ApiException extends AppException {
  const ApiException({
    required this.status,
    required String message,
    this.error,
    this.detail,
  }) : super(message);

  final int status;
  final String? error;
  final String? detail;
}

class PrinterException extends AppException {
  const PrinterException([super.message = 'Error de impresión']);
}

class NfcException extends AppException {
  const NfcException([super.message = 'No se pudo leer la tarjeta']);
}
