/// Ticket QR / token parsing.
///
/// This is a deliberate, behaviour-for-behaviour port of `getTokenFromQr` in
/// the React web app (`src/App.tsx`). The scanner must accept and reject
/// **exactly** the same set of payloads as the app it replaces, quirks
/// included — a door scanner that silently accepts one more URL shape than the
/// web app is a security regression, and one that accepts fewer is a support
/// incident.
library;

/// Only *subdomains* are accepted. Note this means the apex `lacrypta.ar` is
/// **rejected**, because `'lacrypta.ar'.endsWith('.lacrypta.ar')` is false.
/// That is the web app's behaviour and is preserved on purpose.
const String kTicketQrHostSuffix = '.lacrypta.ar';

const List<String> kTicketQrPathPrefixes = ['/ticket/', '/checkin/'];

const List<String> kTicketQrSchemes = ['https', 'http'];

final RegExp _whitespace = RegExp(r'\s');

/// A `%` not followed by two hex digits.
final RegExp _malformedEscape = RegExp('%(?![0-9A-Fa-f]{2})');

/// Extracts a ticket token from a scanned QR payload, or returns `null` if the
/// payload is not a ticket.
///
/// Accepts:
///  * `https://<sub>.lacrypta.ar/ticket/<TOKEN>`
///  * `https://<sub>.lacrypta.ar/checkin/<TOKEN>`
///  * the same over `http`
///  * a **bare token** — any non-empty string with no `/` and no whitespace
///
/// Rejects everything else, including the apex domain, other schemes, other
/// path prefixes, and a trailing slash with no token.
///
/// Query strings and fragments are discarded; only the path is considered.
/// Deeper paths keep their slashes (`/ticket/a/b` yields the token `a/b`),
/// which the API client then percent-encodes back into a single path segment.
String? parseTicketToken(String rawValue) {
  final trimmed = rawValue.trim();
  if (trimmed.isEmpty) return null;

  final Uri uri;
  try {
    final parsed = Uri.parse(trimmed);
    // JavaScript's `new URL(x)` *throws* without a scheme, which routes those
    // inputs to the bare-token fallback. Dart's `Uri.parse` is far more
    // permissive — it happily parses `abc123` (scheme '', path 'abc123') and
    // `//host/path`. Gating on `hasScheme` restores the JS control flow;
    // without it, every bare token would be misread as a relative URL and
    // rejected.
    if (!parsed.hasScheme) return _bareToken(trimmed);
    uri = parsed;
  } on FormatException {
    // Malformed percent-escapes land here. The web app reaches the same branch
    // via `decodeURIComponent` throwing inside the same `try`.
    return _bareToken(trimmed);
  }

  if (!kTicketQrSchemes.contains(uri.scheme)) return null;
  if (!uri.host.endsWith(kTicketQrHostSuffix)) return null;

  // `Uri.path` returns the *raw*, still percent-encoded path — the same thing
  // JavaScript's `URL.pathname` gives — so the prefix is matched against the
  // encoded form (as the web app does) and only the remainder is decoded.
  final path = uri.path;
  final prefix = kTicketQrPathPrefixes.where(path.startsWith).firstOrNull;
  if (prefix == null) return null;

  // Dart silently *normalises* an invalid escape (a lone `%` becomes `%25`)
  // where the WHATWG parser leaves it raw for `decodeURIComponent` to reject.
  // Without this check a malformed URL would be accepted here and rejected by
  // the web app, so we detect it on the original input. Scoped to the path:
  // the web app discards query and fragment before ever decoding.
  final queryStart = trimmed.indexOf(RegExp('[?#]'));
  final rawPath = queryStart < 0 ? trimmed : trimmed.substring(0, queryStart);
  if (_malformedEscape.hasMatch(rawPath)) return null;

  final String token;
  try {
    token = Uri.decodeComponent(path.substring(prefix.length));
  } on ArgumentError {
    return null;
  }
  return token.isEmpty ? null : token;
}

/// The fallback branch: a lone opaque token, as produced by manual entry in
/// earlier versions of the web app. Anything containing a path separator or
/// whitespace is not a token.
String? _bareToken(String trimmed) {
  if (trimmed.contains('/')) return null;
  if (_whitespace.hasMatch(trimmed)) return null;
  return trimmed;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
