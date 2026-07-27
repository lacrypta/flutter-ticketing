import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'nostr_event.dart';
import 'nostr_signer.dart';

/// NIP-98 HTTP Auth (`kind 27235`).
///
/// Written against the **actual verifier** the La Crypta CRM runs
/// (`lib/auth-server.ts`, `authenticateNip98Request`), not just the NIP text.
/// Its checks, in order:
///
/// 1. `Authorization` starts with `Nostr `; the remainder is base64 → UTF-8 →
///    JSON.
/// 2. `kind === 27235`.
/// 3. `pubkey` is a 64-char string and the schnorr signature verifies.
/// 4. `Math.abs(now - created_at) <= 60` — a **60 second** window.
/// 5. the `method` tag equals the request method, uppercased.
/// 6. the `u` tag matches: same origin **and** identical `pathname + search`.
/// 7. when the request has a body, a `payload` tag must be present and equal
///    the lowercase hex SHA-256 of the **raw** body bytes as sent.
/// 8. finally the pubkey is looked up in `users` — so the device key must be
///    registered server-side before any of this grants access.
///
/// The `u` tag is far and away the most common cause of a 401: it must be the
/// exact absolute URL that will be requested, query string included, with no
/// added or stripped trailing slash.
const int kNip98Kind = 27235;

const String kNip98Scheme = 'Nostr ';

/// The server's tolerance for clock skew, in seconds. Mirrored here so the
/// client can warn before it starts failing.
const int kNip98ToleranceSeconds = 60;

/// Builds the value for an `Authorization` header.
///
/// [url] must be the absolute URL of the request being made. [method] is
/// case-insensitive and is uppercased for the tag. [body] must be the exact
/// string that will be written to the wire — hashing a re-encoded copy is a
/// silent 401.
String buildNip98Header({
  required Uri url,
  required String method,
  required String privateKeyHex,
  required DateTime now,
  String? body,
}) {
  final event = buildNip98Event(
    url: url,
    method: method,
    privateKeyHex: privateKeyHex,
    now: now,
    body: body,
  );
  final json = jsonEncode(event.toJson());
  return '$kNip98Scheme${base64.encode(utf8.encode(json))}';
}

/// The signed kind-27235 event, exposed separately so tests can inspect it.
NostrEvent buildNip98Event({
  required Uri url,
  required String method,
  required String privateKeyHex,
  required DateTime now,
  String? body,
}) {
  final tags = <List<String>>[
    ['u', canonicalUrl(url)],
    ['method', method.toUpperCase()],
  ];

  // Only sent when there is a body. The server treats a `payload` tag on an
  // empty-body request as a hard failure unless it happens to equal the hash
  // of the empty string, so omitting it is both simpler and safer.
  if (body != null && body.isNotEmpty) {
    tags.add(['payload', sha256Hex(body)]);
  }

  return signEvent(
    NostrEvent(
      pubkey: '',
      createdAt: now.toUtc().millisecondsSinceEpoch ~/ 1000,
      kind: kNip98Kind,
      tags: tags,
      content: '',
      // `content` MUST be empty per the NIP.
    ),
    privateKeyHex,
  );
}

/// The exact string the server compares the `u` tag against:
/// `origin + pathname + search`, with the fragment dropped.
///
/// Fragments are never transmitted, so signing one guarantees a mismatch.
String canonicalUrl(Uri url) => url.removeFragment().toString();

/// Lowercase hex SHA-256 of a UTF-8 string.
String sha256Hex(String value) => sha256.convert(utf8.encode(value)).toString();
