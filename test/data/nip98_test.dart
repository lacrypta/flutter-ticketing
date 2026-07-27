import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lacrypta_ticketing/data/nostr/nip98.dart';
import 'package:lacrypta_ticketing/data/nostr/nostr_event.dart';
import 'package:lacrypta_ticketing/data/nostr/nostr_signer.dart';

/// A faithful Dart port of the CRM's `authenticateNip98Request`
/// (`lacrypta-crm/lib/auth-server.ts`, lines 283-326).
///
/// The point of duplicating the server's logic here is that these tests fail
/// the moment our client drifts from the thing that will actually reject it in
/// production — which is much cheaper to discover than a 401 at a door with a
/// queue. The only server step not modelled is the final `users` table lookup,
/// which is deployment state rather than protocol.
({String pubkey})? verifyLikeServer(
  String? authHeader, {
  required Uri requestUrl,
  required String method,
  required DateTime now,
  String rawBody = '',
}) {
  if (authHeader == null || !authHeader.startsWith('Nostr ')) return null;

  final NostrEvent event;
  try {
    final raw = utf8.decode(base64.decode(authHeader.substring(6)));
    event = NostrEvent.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  } catch (_) {
    return null;
  }

  if (event.kind != 27235) return null;
  if (event.pubkey.length != 64) return null;
  if (!verifyEvent(event)) return null;

  final nowSeconds = now.toUtc().millisecondsSinceEpoch ~/ 1000;
  if ((nowSeconds - event.createdAt).abs() > 60) return null;

  if (event.tagValue('method') != method.toUpperCase()) return null;

  final urlTag = event.tagValue('u');
  if (urlTag == null) return null;
  final signed = Uri.parse(urlTag);
  final signedPath = '${signed.path}${_search(signed)}';
  final actualPath = '${requestUrl.path}${_search(requestUrl)}';
  if (signed.origin != requestUrl.origin || signedPath != actualPath) {
    return null;
  }

  final payloadTag = event.tagValue('payload');
  if (rawBody.isNotEmpty) {
    if (payloadTag == null || payloadTag != sha256Hex(rawBody)) return null;
  } else if (payloadTag != null && payloadTag != sha256Hex('')) {
    return null;
  }

  return (pubkey: event.pubkey);
}

String _search(Uri uri) => uri.hasQuery ? '?${uri.query}' : '';

void main() {
  // A fixed key so the vectors are reproducible.
  const privateKey =
      '5b4f8e2c1a9d7f3b6e0c8a5d2f4b1e9c7a3d6f0b8e2c5a9d1f7b3e6c0a8d5f2b';
  final publicKey = derivePublicKey(privateKey);
  final now = DateTime.utc(2026, 7, 27, 12, 0, 0);
  final url = Uri.parse('https://events.lacrypta.ar/api/checkin/ABC123');

  group('buildNip98Event — shape required by the NIP', () {
    test('uses kind 27235 with empty content', () {
      final event = buildNip98Event(
        url: url,
        method: 'GET',
        privateKeyHex: privateKey,
        now: now,
      );
      expect(event.kind, 27235);
      expect(event.content, '');
    });

    test('carries u and method tags', () {
      final event = buildNip98Event(
        url: url,
        method: 'get',
        privateKeyHex: privateKey,
        now: now,
      );
      expect(
        event.tagValue('u'),
        'https://events.lacrypta.ar/api/checkin/ABC123',
      );
      expect(event.tagValue('method'), 'GET', reason: 'method is uppercased');
    });

    test('created_at is unix SECONDS, not milliseconds', () {
      final event = buildNip98Event(
        url: url,
        method: 'GET',
        privateKeyHex: privateKey,
        now: now,
      );
      expect(event.createdAt, now.millisecondsSinceEpoch ~/ 1000);
      expect(event.createdAt.toString().length, 10);
    });

    test('signs with the device key and the id verifies', () {
      final event = buildNip98Event(
        url: url,
        method: 'GET',
        privateKeyHex: privateKey,
        now: now,
      );
      expect(event.pubkey, publicKey);
      expect(event.id, event.computedId);
      expect(verifyEvent(event), isTrue);
    });

    test('omits the payload tag when there is no body', () {
      final event = buildNip98Event(
        url: url,
        method: 'POST',
        privateKeyHex: privateKey,
        now: now,
      );
      expect(event.tagValue('payload'), isNull);
    });

    test('adds a sha256 payload tag when there is a body', () {
      const body = '{"pizza_porcion":1}';
      final event = buildNip98Event(
        url: url,
        method: 'POST',
        privateKeyHex: privateKey,
        now: now,
        body: body,
      );
      expect(event.tagValue('payload'), sha256Hex(body));
      expect(event.tagValue('payload'), hasLength(64));
    });
  });

  group('buildNip98Header — encoding', () {
    test('uses the "Nostr " scheme followed by padded base64 JSON', () {
      final header = buildNip98Header(
        url: url,
        method: 'GET',
        privateKeyHex: privateKey,
        now: now,
      );
      expect(header, startsWith('Nostr '));

      final decoded = utf8.decode(base64.decode(header.substring(6)));
      expect(decoded, startsWith('{'));

      final json = jsonDecode(decoded) as Map<String, dynamic>;
      expect(json['kind'], 27235);
      expect(json['sig'], isA<String>());
      expect((json['sig']! as String).length, 128);
      expect(json['id'], isA<String>());
      expect((json['id']! as String).length, 64);
    });

    test('drops the fragment, which is never sent on the wire', () {
      final event = buildNip98Event(
        url: Uri.parse('https://events.lacrypta.ar/api/checkin/A#frag'),
        method: 'GET',
        privateKeyHex: privateKey,
        now: now,
      );
      expect(event.tagValue('u'), 'https://events.lacrypta.ar/api/checkin/A');
    });

    test('preserves the query string, which IS compared', () {
      final withQuery = Uri.parse(
        'https://events.lacrypta.ar/api/checkin/A?full=1',
      );
      final event = buildNip98Event(
        url: withQuery,
        method: 'GET',
        privateKeyHex: privateKey,
        now: now,
      );
      expect(
        event.tagValue('u'),
        'https://events.lacrypta.ar/api/checkin/A?full=1',
      );
    });
  });

  group('accepted by a port of the real server verifier', () {
    test('a GET with no body', () {
      final header = buildNip98Header(
        url: url,
        method: 'GET',
        privateKeyHex: privateKey,
        now: now,
      );
      final result = verifyLikeServer(
        header,
        requestUrl: url,
        method: 'GET',
        now: now,
      );
      expect(result?.pubkey, publicKey);
    });

    test('a POST with no body — the check-in call', () {
      final header = buildNip98Header(
        url: url,
        method: 'POST',
        privateKeyHex: privateKey,
        now: now,
      );
      expect(
        verifyLikeServer(header, requestUrl: url, method: 'POST', now: now),
        isNotNull,
      );
    });

    test('a POST with a JSON body — the gift consume call', () {
      const body = '{"pizza_porcion":1}';
      final consumeUrl = Uri.parse(
        'https://events.lacrypta.ar/api/checkin/ABC123/gifts/consume',
      );
      final header = buildNip98Header(
        url: consumeUrl,
        method: 'POST',
        privateKeyHex: privateKey,
        now: now,
        body: body,
      );
      expect(
        verifyLikeServer(
          header,
          requestUrl: consumeUrl,
          method: 'POST',
          now: now,
          rawBody: body,
        ),
        isNotNull,
      );
    });

    test('a URL carrying a query string', () {
      final q = Uri.parse('https://events.lacrypta.ar/api/checkin/A?x=1&y=2');
      final header = buildNip98Header(
        url: q,
        method: 'GET',
        privateKeyHex: privateKey,
        now: now,
      );
      expect(
        verifyLikeServer(header, requestUrl: q, method: 'GET', now: now),
        isNotNull,
      );
    });

    test('a percent-encoded token in the path', () {
      final encoded = Uri.parse(
        'https://events.lacrypta.ar/api/checkin/${Uri.encodeComponent('a/b')}',
      );
      final header = buildNip98Header(
        url: encoded,
        method: 'GET',
        privateKeyHex: privateKey,
        now: now,
      );
      expect(
        verifyLikeServer(header, requestUrl: encoded, method: 'GET', now: now),
        isNotNull,
      );
    });
  });

  group('rejected by the server verifier', () {
    String header({
      Uri? signUrl,
      String method = 'GET',
      DateTime? signedAt,
      String? body,
    }) => buildNip98Header(
      url: signUrl ?? url,
      method: method,
      privateKeyHex: privateKey,
      now: signedAt ?? now,
      body: body,
    );

    test('a missing header', () {
      expect(
        verifyLikeServer(null, requestUrl: url, method: 'GET', now: now),
        isNull,
      );
    });

    test('a Bearer scheme', () {
      expect(
        verifyLikeServer(
          'Bearer abc',
          requestUrl: url,
          method: 'GET',
          now: now,
        ),
        isNull,
      );
    });

    test('a different path than was signed', () {
      expect(
        verifyLikeServer(
          header(),
          requestUrl: Uri.parse('https://events.lacrypta.ar/api/checkin/OTHER'),
          method: 'GET',
          now: now,
        ),
        isNull,
      );
    });

    test('a different origin than was signed', () {
      expect(
        verifyLikeServer(
          header(),
          requestUrl: Uri.parse('https://evil.example.com/api/checkin/ABC123'),
          method: 'GET',
          now: now,
        ),
        isNull,
      );
    });

    test('a mismatched method', () {
      expect(
        verifyLikeServer(
          header(method: 'GET'),
          requestUrl: url,
          method: 'POST',
          now: now,
        ),
        isNull,
      );
    });

    test('a query string added after signing', () {
      expect(
        verifyLikeServer(
          header(),
          requestUrl: Uri.parse(
            'https://events.lacrypta.ar/api/checkin/ABC123?x=1',
          ),
          method: 'GET',
          now: now,
        ),
        isNull,
      );
    });

    test('a body that does not match the payload hash', () {
      expect(
        verifyLikeServer(
          header(method: 'POST', body: '{"a":1}'),
          requestUrl: url,
          method: 'POST',
          now: now,
          rawBody: '{"a":2}',
        ),
        isNull,
      );
    });

    test('a body sent without a payload tag', () {
      expect(
        verifyLikeServer(
          header(method: 'POST'),
          requestUrl: url,
          method: 'POST',
          now: now,
          rawBody: '{"a":1}',
        ),
        isNull,
      );
    });

    test('a tampered signature', () {
      final good = header();
      final event =
          jsonDecode(utf8.decode(base64.decode(good.substring(6))))
              as Map<String, dynamic>;
      event['created_at'] = (event['created_at']! as int) + 1; // breaks the id
      final forged = 'Nostr ${base64.encode(utf8.encode(jsonEncode(event)))}';
      expect(
        verifyLikeServer(forged, requestUrl: url, method: 'GET', now: now),
        isNull,
      );
    });
  });

  group('the 60 second clock-skew window', () {
    String at(DateTime signedAt) => buildNip98Header(
      url: url,
      method: 'GET',
      privateKeyHex: privateKey,
      now: signedAt,
    );

    test('accepts 59 seconds in the past', () {
      expect(
        verifyLikeServer(
          at(now.subtract(const Duration(seconds: 59))),
          requestUrl: url,
          method: 'GET',
          now: now,
        ),
        isNotNull,
      );
    });

    test('accepts exactly 60 seconds (the bound is inclusive)', () {
      expect(
        verifyLikeServer(
          at(now.subtract(const Duration(seconds: 60))),
          requestUrl: url,
          method: 'GET',
          now: now,
        ),
        isNotNull,
      );
    });

    test('rejects 61 seconds in the past', () {
      expect(
        verifyLikeServer(
          at(now.subtract(const Duration(seconds: 61))),
          requestUrl: url,
          method: 'GET',
          now: now,
        ),
        isNull,
      );
    });

    test(
      'rejects 61 seconds in the FUTURE — a fast device clock also fails',
      () {
        expect(
          verifyLikeServer(
            at(now.add(const Duration(seconds: 61))),
            requestUrl: url,
            method: 'GET',
            now: now,
          ),
          isNull,
        );
      },
    );

    test('the advertised tolerance constant matches the server', () {
      expect(kNip98ToleranceSeconds, 60);
    });
  });
}
