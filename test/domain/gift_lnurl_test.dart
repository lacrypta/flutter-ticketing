import 'package:flutter_test/flutter_test.dart';
import 'package:lacrypta_ticketing/domain/ticket/gift.dart';

void main() {
  const lnurl =
      'lnurl1dp68gurn8ghj7mrww4exctt5dahkccn00qhxget8wfjkxmmww3jhxaq0v3jk6mnyv4ej7mrww4exctn9v4jk6mnyv4ej7mr0va5kuer';

  Gift chest(String? value) => Gift(
    id: 'chest',
    label: 'Treasure',
    kind: 'sats_treasure',
    lnurl: value,
    satsAmount: 210,
  );

  test('a LUD-03 QR payload is a lightning deeplink', () {
    expect(chest(lnurl).lightningLnurl, 'lightning:$lnurl');
  });

  test('an existing lightning: prefix is kept once', () {
    expect(chest('lightning:$lnurl').lightningLnurl, 'lightning:$lnurl');
    expect(chest('LIGHTNING:$lnurl').lightningLnurl, 'LIGHTNING:$lnurl');
  });

  test('whitespace around the LNURL is trimmed before the scheme', () {
    expect(chest('  $lnurl  ').lightningLnurl, 'lightning:$lnurl');
  });

  test('a missing LNURL has no QR payload', () {
    expect(chest(null).lightningLnurl, isNull);
    expect(chest('  ').lightningLnurl, isNull);
  });
}
