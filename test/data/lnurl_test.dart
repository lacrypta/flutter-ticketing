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
          payLink: pay,
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

    test(
      'a card JSON payload is enough when it already includes payLink',
      () async {
        final link = await CardPayLink(
          _Script(const {}),
        ).resolve('{"tag":"withdrawRequest","payLink":"$pay"}');
        expect(link, pay);
      },
    );
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
