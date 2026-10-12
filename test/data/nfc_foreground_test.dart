import 'package:flutter_test/flutter_test.dart';
import 'package:lacrypta_ticketing/core/error/app_exception.dart';
import 'package:lacrypta_ticketing/data/nfc/nfc_foreground.dart';
import 'package:nfc_manager/nfc_manager.dart';

void main() {
  test('a tap with nobody waiting is consumed and not read', () async {
    final harness = _Harness();
    await harness.reader.hold();

    harness.tap();
    await Future<void>.delayed(Duration.zero);

    expect(harness.reads, 0);
    expect(harness.reader.isHeld, isTrue);
    expect(harness.unbound, 0);
  });

  test('a waiting claim receives the card and the reader stays up', () async {
    final harness = _Harness();
    await harness.reader.hold();

    final card = harness.reader.waitForCard();
    harness.tap();

    expect(await card, 'https://card.example/u/1');
    expect(harness.reads, 1);

    harness.tap();
    await Future<void>.delayed(Duration.zero);
    expect(harness.reads, 1);
    expect(harness.reader.isHeld, isTrue);
  });

  test('cancelling a wait does not give NFC back to the system', () async {
    final harness = _Harness();
    await harness.reader.hold();

    final card = harness.reader.waitForCard();
    harness.reader.cancelWait();

    expect(card, throwsA(isA<NfcReadCancelled>()));
    expect(harness.unbound, 0);
    expect(harness.reader.isHeld, isTrue);
  });

  test('leaving the foreground unbinds the reader', () async {
    final harness = _Harness();
    await harness.reader.hold();

    await harness.reader.release();

    expect(harness.reader.isHeld, isFalse);
    expect(harness.unbound, 1);
  });
}

class _Harness {
  _Harness() {
    reader = NfcForeground(
      bind: (onTag) async {
        this.onTag = onTag;
      },
      unbind: () async {
        unbound++;
      },
      payload: (_) async {
        reads++;
        return 'https://card.example/u/1';
      },
    );
  }

  late final NfcForeground reader;
  void Function(NfcTag tag)? onTag;
  var reads = 0;
  var unbound = 0;

  void tap() => onTag?.call(const NfcTag(data: 'tag'));
}
