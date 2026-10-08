import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lacrypta_ticketing/core/error/app_exception.dart';
import 'package:lacrypta_ticketing/data/nfc/ndef_payload.dart';
import 'package:nfc_manager/ndef_record.dart';

void main() {
  test('a URI record comes back as an https link', () {
    final message = NdefMessage(
      records: [
        NdefRecord(
          typeNameFormat: TypeNameFormat.wellKnown,
          type: Uint8List.fromList([0x55]),
          identifier: Uint8List(0),
          payload: Uint8List.fromList([
            0x04,
            ...utf8.encode('card.example/u/1'),
          ]),
        ),
      ],
    );

    expect(cardPayloadFromNdef(message), 'https://card.example/u/1');
  });

  test('a text record can carry the lnurl itself', () {
    final message = NdefMessage(
      records: [
        NdefRecord(
          typeNameFormat: TypeNameFormat.wellKnown,
          type: Uint8List.fromList([0x54]),
          identifier: Uint8List(0),
          payload: Uint8List.fromList([
            0x02,
            ...utf8.encode('en'),
            ...utf8.encode('lnurl1dp68gurn8ghj7'),
          ]),
        ),
      ],
    );

    expect(cardPayloadFromNdef(message), 'lnurl1dp68gurn8ghj7');
  });

  test('an empty tag is a failed read, not a payment', () {
    expect(
      () => cardPayloadFromNdef(const NdefMessage(records: [])),
      throwsA(isA<NfcException>()),
    );
  });
}
