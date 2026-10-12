import 'dart:async';

import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';

import '../../core/error/app_exception.dart';
import 'ndef_payload.dart';

/// Binds the Android reader. The callback replaces any previous one.
typedef NfcReaderBind = Future<void> Function(void Function(NfcTag tag) onTag);

/// Drops reader mode so the system may dispatch tags again.
typedef NfcReaderUnbind = Future<void> Function();

/// Android reader mode for the whole time the app is in front.
///
/// Android reader mode is the only way a foreground activity keeps a tap from
/// becoming a system intent (the tag viewer, a browser, a wallet).
/// The session stays up on every screen. A tap is delivered only when someone
/// is waiting for a card; every other tap is consumed and dropped.
class NfcForeground {
  NfcForeground({
    required this._bind,
    required this._unbind,
    Future<String> Function(NfcTag tag)? payload,
  }) : _payload = payload ?? _ndefPayload;

  static NfcForeground? _instance;

  static NfcForeground get instance => _instance ??= NfcForeground(
    bind: (onTag) => NfcManagerAndroid.instance.enableReaderMode(
      flags: const {
        NfcReaderFlagAndroid.nfcA,
        NfcReaderFlagAndroid.nfcB,
        NfcReaderFlagAndroid.nfcF,
        NfcReaderFlagAndroid.nfcV,
        NfcReaderFlagAndroid.nfcBarcode,
      },
      onTagDiscovered: onTag,
    ),
    unbind: NfcManagerAndroid.instance.disableReaderMode,
  );

  final NfcReaderBind _bind;
  final NfcReaderUnbind _unbind;
  final Future<String> Function(NfcTag tag) _payload;

  Completer<String>? _waiter;
  bool _held = false;
  bool _reading = false;
  int _generation = 0;

  bool get isHeld => _held;

  /// Turns reader mode on. Safe to call again after a resume: Android drops
  /// the mode while the activity is paused and only restores it if it was
  /// never disabled.
  Future<void> hold() async {
    final generation = ++_generation;
    try {
      await _bind(_onTag);
    } catch (_) {
      return;
    }
    if (generation != _generation) {
      try {
        await _unbind();
      } catch (_) {}
      return;
    }
    _held = true;
  }

  /// Gives NFC back to the system. Used when the app leaves the foreground.
  Future<void> release() async {
    _generation++;
    cancelWait();
    if (!_held) return;
    _held = false;
    try {
      await _unbind();
    } catch (_) {}
  }

  /// The next card that lands while reader mode is held.
  ///
  /// Does not start or stop the session. Stopping it is what lets the
  /// following tap escape to the system.
  Future<String> waitForCard() {
    final current = _waiter;
    if (current != null && !current.isCompleted) {
      return Future<String>.error(
        const NfcException('Ya hay una lectura en curso'),
      );
    }
    final completer = Completer<String>();
    _waiter = completer;
    return completer.future;
  }

  /// Drops the waiter. Reader mode stays on.
  void cancelWait() {
    final pending = _waiter;
    _waiter = null;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(const NfcReadCancelled());
    }
  }

  void _onTag(NfcTag tag) {
    unawaited(_handle(tag));
  }

  Future<void> _handle(NfcTag tag) async {
    final waiter = _waiter;
    // Nobody asked for this card. Reader mode already ate the event, so the
    // system will not open it. Drop it.
    if (waiter == null || waiter.isCompleted || _reading) return;
    _reading = true;
    try {
      final payload = await _payload(tag);
      if (!waiter.isCompleted) waiter.complete(payload);
    } catch (error) {
      if (!waiter.isCompleted) {
        waiter.completeError(
          error is NfcException ? error : NfcException('$error'),
        );
      }
    } finally {
      _reading = false;
      if (identical(_waiter, waiter)) _waiter = null;
    }
  }
}

Future<String> _ndefPayload(NfcTag tag) async {
  final ndef = Ndef.from(tag);
  final message = ndef?.cachedMessage ?? await ndef?.read();
  try {
    return cardPayloadFromNdef(message);
  } on NfcException catch (error) {
    throw NfcException(error.message, describeNdef(message));
  }
}
