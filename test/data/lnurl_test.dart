import 'package:flutter_test/flutter_test.dart';
import 'package:lacrypta_ticketing/data/lnurl/lnurl.dart';

void main() {
  const prize = 'https://prize.example/lnurl/chest';
  const pay = 'https://wallet.example/.well-known/lnurlp/ada';

  group('decodeLnurl', () {
    test('round-trips a bech32 withdraw link', () {
      expect(decodeLnurl(encodeLnurl(prize)).toString(), prize);
    });

    test('accepts a lightning address as a pay link', () {
      expect(decodeLnurl('ada@wallet.example').toString(), pay);
    });

    test('rejects a string that is not a payment link', () {
      expect(() => decodeLnurl('nope'), throwsA(isA<LnurlException>()));
    });

    test('lnurlp:// is fetched as https', () {
      expect(
        decodeLnurl(
          'lnurlp://wallet.example/.well-known/lnurlp/ada',
        ).toString(),
        pay,
      );
    });

    test('lnurlp:// accepts a bech32 LNURL', () {
      expect(decodeLnurl('lnurlp://${encodeLnurl(pay)}').toString(), pay);
    });

    test('a bech32 longer than 90 characters still decodes', () {
      final url = 'https://prize.example/lnurl/${'chest-' * 20}';
      final encoded = encodeLnurl(url);
      expect(encoded.length, greaterThan(90));
      expect(decodeLnurl(encoded).toString(), url);
      expect(decodeLnurl('lnurlp://$encoded').toString(), url);
    });
  });

  group('lnurlw://', () {
    test('a host without a scheme is fetched over https', () {
      expect(
        lnurlwUri('lnurlw://card.example/w/1').toString(),
        'https://card.example/w/1',
      );
    });

    test('a full URL after the scheme is fetched as written', () {
      expect(
        lnurlwUri('LNURLW://https://card.example/w/1').toString(),
        'https://card.example/w/1',
      );
    });

    test('anything else is refused', () {
      expect(
        () => lnurlwUri('https://card.example/w/1'),
        throwsA(
          isA<LnurlException>().having(
            (error) => error.message,
            'message',
            'Se esperaba lnurlw://{link}',
          ),
        ),
      );
    });
  });

  group('LUD-19 payLink', () {
    test('reads payLink off a withdraw response', () {
      expect(
        payLinkFrom({
          'tag': 'withdrawRequest',
          'callback': 'https://card.example/cb',
          'k1': 'abc',
          'payLink': pay,
        }),
        pay,
      );
    });

    test('a card without payLink is refused', () {
      expect(
        () => payLinkFrom({'tag': 'withdrawRequest', 'k1': 'abc'}),
        throwsA(
          isA<LnurlException>().having(
            (error) => error.message,
            'message',
            'La tarjeta no tiene un link de cobro',
          ),
        ),
      );
    });
  });

  group('paying a treasure into the card', () {
    test(
      'asks the pay link for an invoice and submits it to the withdraw',
      () async {
        final transport = _Script({
          prize: {
            'tag': 'withdrawRequest',
            'callback': 'https://prize.example/withdraw',
            'k1': 'k1-chest',
            'minWithdrawable': 210000,
            'maxWithdrawable': 210000,
          },
          pay: {
            'tag': 'payRequest',
            'callback': 'https://wallet.example/invoice',
            'minSendable': 1000,
            'maxSendable': 1000000000,
          },
          'https://wallet.example/invoice': {
            'pr': 'lnbc2100n1example',
            'routes': <Object>[],
          },
          'https://prize.example/withdraw': {'status': 'OK'},
        });

        await LnurlPayer(transport).payWithdrawTo(
          withdrawLnurl: encodeLnurl(prize),
          payLink: 'lnurlp://wallet.example/.well-known/lnurlp/ada',
          sats: 210,
        );

        expect(transport.calls, [
          prize,
          pay,
          'https://wallet.example/invoice?amount=210000',
          'https://prize.example/withdraw?k1=k1-chest&pr=lnbc2100n1example',
        ]);
      },
    );

    test(
      'an ERROR from the prize does not ask the card for an invoice',
      () async {
        final transport = _Script({
          prize: {'status': 'ERROR', 'reason': 'ya cobrado'},
        });

        expect(
          () => LnurlPayer(
            transport,
          ).payWithdrawTo(withdrawLnurl: prize, payLink: pay, sats: 210),
          throwsA(
            isA<LnurlException>().having(
              (error) => error.message,
              'message',
              'ya cobrado',
            ),
          ),
        );
        expect(transport.calls, [prize]);
      },
    );

    test('fetches the link and reads payLink off the LUD-03', () async {
      final transport = _Script({
        'https://card.example/w/1': {
          'tag': 'withdrawRequest',
          'callback': 'https://card.example/cb',
          'k1': 'abc',
          'minWithdrawable': 0,
          'maxWithdrawable': 0,
          'payLink': pay,
        },
      });

      final card = await CardPayLink(
        transport,
      ).resolve('lnurlw://card.example/w/1');

      expect(card.url, 'https://card.example/w/1');
      expect(card.payLink, pay);
      expect(card.json['tag'], 'withdrawRequest');
      expect(transport.calls, ['https://card.example/w/1']);
    });

    test('a LUD-03 without payLink keeps the json for the screen', () {
      final transport = _Script({
        'https://card.example/w/1': {'tag': 'withdrawRequest', 'k1': 'abc'},
      });

      expect(
        () =>
            CardPayLink(transport).resolve('lnurlw://https://card.example/w/1'),
        throwsA(
          isA<LnurlException>()
              .having(
                (error) => error.message,
                'message',
                'La tarjeta no tiene un link de cobro',
              )
              .having((error) => error.link, 'link', 'https://card.example/w/1')
              .having(
                (error) => error.response,
                'response',
                contains('"tag": "withdrawRequest"'),
              ),
        ),
      );
    });
  });
}

class _Script implements LnurlTransport {
  _Script(this._bodies);

  final Map<String, Map<String, dynamic>> _bodies;
  final calls = <String>[];

  @override
  Future<Map<String, dynamic>> get(Uri uri) async {
    final key = '${uri.scheme}://${uri.host}${uri.path}';
    calls.add(uri.toString());
    final body = _bodies[key];
    if (body == null) throw StateError('unexpected $uri');
    return body;
  }
}
