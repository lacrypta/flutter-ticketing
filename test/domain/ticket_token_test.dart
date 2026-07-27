import 'package:flutter_test/flutter_test.dart';
import 'package:lacrypta_ticketing/domain/ticket/ticket_token.dart';

void main() {
  group('parseTicketToken — accepts', () {
    test('a /ticket/ URL on a lacrypta subdomain', () {
      expect(
        parseTicketToken('https://events.lacrypta.ar/ticket/ABC123'),
        'ABC123',
      );
    });

    test('a /checkin/ URL', () {
      expect(
        parseTicketToken('https://checkin.lacrypta.ar/checkin/ABC123'),
        'ABC123',
      );
    });

    test('http as well as https', () {
      expect(parseTicketToken('http://events.lacrypta.ar/ticket/T'), 'T');
    });

    test('a deep subdomain', () {
      expect(parseTicketToken('https://a.b.lacrypta.ar/ticket/T'), 'T');
    });

    test('an uppercase host (the URL parser lowercases it)', () {
      expect(parseTicketToken('https://EVENTS.LACRYPTA.AR/ticket/T'), 'T');
    });

    test('a bare token', () {
      expect(parseTicketToken('ABC123'), 'ABC123');
    });

    test('a bare token with surrounding whitespace, trimmed', () {
      expect(parseTicketToken('   ABC123 \n'), 'ABC123');
    });

    test('a bare token that looks like a hex id', () {
      expect(parseTicketToken('deadbeef00ff'), 'deadbeef00ff');
    });
  });

  group('parseTicketToken — URL component handling', () {
    test('discards the query string', () {
      expect(
        parseTicketToken('https://events.lacrypta.ar/ticket/ABC?utm=qr&x=1'),
        'ABC',
      );
    });

    test('discards the fragment', () {
      expect(
        parseTicketToken('https://events.lacrypta.ar/ticket/ABC#section'),
        'ABC',
      );
    });

    test('keeps slashes in a deeper path', () {
      expect(parseTicketToken('https://events.lacrypta.ar/ticket/a/b'), 'a/b');
    });

    test('percent-decodes the token exactly once', () {
      // `%2B` must become `+`, not stay `%2B` and not decode twice.
      expect(
        parseTicketToken('https://events.lacrypta.ar/ticket/a%2Bb'),
        'a+b',
      );
    });

    test('percent-decodes an encoded slash', () {
      expect(
        parseTicketToken('https://events.lacrypta.ar/ticket/a%2Fb'),
        'a/b',
      );
    });

    test('percent-decodes a space', () {
      expect(
        parseTicketToken('https://events.lacrypta.ar/ticket/a%20b'),
        'a b',
      );
    });

    test('handles a token with a trailing empty segment as a deep path', () {
      expect(parseTicketToken('https://events.lacrypta.ar/ticket/a/'), 'a/');
    });
  });

  group('parseTicketToken — rejects', () {
    test('the apex domain (documented quirk: only subdomains are valid)', () {
      expect(parseTicketToken('https://lacrypta.ar/ticket/ABC'), isNull);
    });

    test('a lookalike host that merely contains the suffix', () {
      expect(
        parseTicketToken('https://evil.lacrypta.ar.attacker.com/ticket/ABC'),
        isNull,
      );
    });

    test('a host that ends with the suffix without the dot', () {
      expect(parseTicketToken('https://notlacrypta.ar/ticket/ABC'), isNull);
    });

    test('a non-http(s) scheme', () {
      expect(parseTicketToken('ftp://events.lacrypta.ar/ticket/ABC'), isNull);
    });

    test('a javascript: payload', () {
      expect(parseTicketToken('javascript:alert(1)'), isNull);
    });

    test('a mailto: payload', () {
      expect(parseTicketToken('mailto:someone@lacrypta.ar'), isNull);
    });

    test('an unrelated path prefix', () {
      expect(parseTicketToken('https://events.lacrypta.ar/other/ABC'), isNull);
    });

    test('a prefix that is only a substring match', () {
      expect(
        parseTicketToken('https://events.lacrypta.ar/tickets/ABC'),
        isNull,
      );
    });

    test('a trailing slash with no token', () {
      expect(parseTicketToken('https://events.lacrypta.ar/ticket/'), isNull);
    });

    test('the bare path with no trailing slash', () {
      expect(parseTicketToken('https://events.lacrypta.ar/ticket'), isNull);
    });

    test('the site root', () {
      expect(parseTicketToken('https://events.lacrypta.ar'), isNull);
    });

    test('an empty string', () {
      expect(parseTicketToken(''), isNull);
    });

    test('whitespace only', () {
      expect(parseTicketToken('   \t\n '), isNull);
    });

    test('a bare string containing a slash', () {
      expect(parseTicketToken('abc/def'), isNull);
    });

    test('a bare string containing whitespace', () {
      expect(parseTicketToken('abc def'), isNull);
    });

    test('a protocol-relative URL', () {
      // No scheme → bare-token fallback → contains '/' → rejected.
      expect(parseTicketToken('//events.lacrypta.ar/ticket/ABC'), isNull);
    });

    test('a relative path', () {
      expect(parseTicketToken('/ticket/ABC'), isNull);
    });

    test('a malformed percent-escape', () {
      // Dart throws FormatException where JS throws inside decodeURIComponent;
      // both land in the fallback branch, and the '/' rejects it.
      expect(
        parseTicketToken('https://events.lacrypta.ar/ticket/100%'),
        isNull,
      );
    });

    test('a plain sentence', () {
      expect(parseTicketToken('hola que tal'), isNull);
    });
  });

  group('parseTicketToken — round trip into an API path', () {
    test('a token with a slash re-encodes to a single path segment', () {
      final token = parseTicketToken('https://events.lacrypta.ar/ticket/a/b');
      expect(token, 'a/b');
      expect(Uri.encodeComponent(token!), 'a%2Fb');
    });
  });
}
