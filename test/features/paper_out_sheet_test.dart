import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lacrypta_ticketing/data/printer/printer_channel.dart';
import 'package:lacrypta_ticketing/features/ticket/paper_out_sheet.dart';

/// Opens the sheet from a bare app and exposes what it resolved to.
Future<Completer<String?>> _open(
  WidgetTester tester,
  Future<String?> Function() reprint,
) async {
  final result = Completer<String?>();
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => result.complete(
              await showPaperOutSheet(
                context,
                gift: 'Remera',
                reprint: reprint,
              ),
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets('reprints the whole slip until the roll is back', (tester) async {
    final outcomes = <String?>[PrinterChannel.paperOut, null];
    var calls = 0;
    final result = await _open(tester, () async {
      calls++;
      return outcomes.removeAt(0);
    });

    expect(find.text('Se cortó el cupón'), findsOneWidget);

    await tester.tap(find.text('Reimprimir cupón'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.textContaining('Sigue sin papel'), findsOneWidget);
    expect(result.isCompleted, isFalse);

    await tester.tap(find.text('Reimprimir cupón'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('Se cortó el cupón'), findsNothing);
    expect(await result.future, isNull);
  });

  testWidgets('hands back any other printer fault', (tester) async {
    final result = await _open(tester, () async => PrinterChannel.overheated);

    await tester.tap(find.text('Reimprimir cupón'));
    await tester.pumpAndSettle();
    expect(await result.future, PrinterChannel.overheated);
  });

  testWidgets('giving up leaves the slip unprinted', (tester) async {
    var calls = 0;
    final result = await _open(tester, () async {
      calls++;
      return null;
    });

    await tester.tap(find.text('MOSTRAR EN PANTALLA'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(await result.future, PrinterChannel.paperOut);
  });

  testWidgets('a tap on the backdrop does not dismiss it', (tester) async {
    final result = await _open(tester, () async => null);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('Se cortó el cupón'), findsOneWidget);
    expect(result.isCompleted, isFalse);
  });
}
