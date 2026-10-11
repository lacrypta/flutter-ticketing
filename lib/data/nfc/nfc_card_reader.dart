import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_ios.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';

import '../../core/error/app_exception.dart';
import 'ndef_payload.dart';
import 'nfc_foreground.dart';

export '../../core/error/app_exception.dart' show NfcReadCancelled;

/// One tap, one NDEF payload.
///
/// On Android the app already holds reader mode ([NfcForeground]), so this
/// only waits for the next card and never disables the session. iOS presents
/// the system sheet for this single read — Core NFC will not listen otherwise.
class NfcCardReader {
  Completer<String>? _pending;

  Future<NfcAvailability> availability() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return NfcAvailability.unsupported;
    }
    try {
      return await NfcManager.instance.checkAvailability();
    } catch (_) {
      return NfcAvailability.unsupported;
    }
  }

  Future<String> readOnce({required String prompt}) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return NfcForeground.instance.waitForCard();
    }
    final current = _pending;
    if (current != null && !current.isCompleted) {
      return Future<String>.error(
        const NfcException('Ya hay una lectura en curso'),
      );
    }
    final completer = Completer<String>();
    _pending = completer;
    unawaited(_start(completer, prompt));
    return completer.future;
  }

  Future<void> cancel() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      NfcForeground.instance.cancelWait();
      return;
    }
    final pending = _pending;
    _pending = null;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(const NfcReadCancelled());
    }
    await _stop();
  }

  Future<void> _start(Completer<String> completer, String prompt) async {
    try {
      await NfcManager.instance.startSession(
        pollingOptions: {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
          NfcPollingOption.iso18092,
        },
        alertMessageIos: prompt,
        // We close the sheet ourselves after the payload is in hand. Letting
        // iOS invalidate on first read races the NDEF read and drops the card.
        invalidateAfterFirstReadIos: false,
        onDiscovered: (tag) {
          unawaited(_onTag(tag, completer));
        },
        onSessionErrorIos: (error) {
          if (completer.isCompleted) return;
          final cancelled =
              error.code ==
              NfcReaderErrorCodeIos.readerSessionInvalidationErrorUserCanceled;
          completer.completeError(
            cancelled
                ? const NfcReadCancelled()
                : NfcException(
                    error.message.isEmpty
                        ? 'No se pudo leer la tarjeta'
                        : error.message,
                  ),
          );
          _pending = null;
        },
      );
    } catch (_) {
      if (!completer.isCompleted) {
        completer.completeError(const NfcException());
      }
      _pending = null;
    }
  }

  Future<void> _onTag(NfcTag tag, Completer<String> completer) async {
    if (completer.isCompleted) return;
    try {
      final ndef = Ndef.from(tag);
      final message = ndef?.cachedMessage ?? await ndef?.read();
      final payload = cardPayloadFromNdef(message);
      if (!completer.isCompleted) completer.complete(payload);
      await _stop(alertMessageIos: 'Tarjeta leída');
    } catch (error) {
      if (!completer.isCompleted) {
        completer.completeError(
          error is NfcException ? error : const NfcException(),
        );
      }
      await _stop(errorMessageIos: 'No se pudo leer la tarjeta');
    } finally {
      if (identical(_pending, completer)) _pending = null;
    }
  }

  Future<void> _stop({String? alertMessageIos, String? errorMessageIos}) async {
    try {
      await NfcManager.instance.stopSession(
        alertMessageIos: alertMessageIos,
        errorMessageIos: errorMessageIos,
      );
    } catch (_) {
      // The session was already closed by the system sheet.
    }
  }
}
