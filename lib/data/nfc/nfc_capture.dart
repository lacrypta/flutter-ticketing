import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'nfc_foreground.dart';

/// Keeps Android reader mode on for as long as this app is in front.
///
/// Paused, hidden and detached give the radio back. [AppLifecycleState.inactive]
/// does not: that state is a dialog or the notification shade, and a card
/// landing there must still not escape to the system.
class NfcCapture extends StatefulWidget {
  const NfcCapture({required this.child, super.key});

  final Widget child;

  @override
  State<NfcCapture> createState() => _NfcCaptureState();
}

class _NfcCaptureState extends State<NfcCapture> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _hold();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _release();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _hold();
        break;
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _release();
        break;
    }
  }

  void _hold() {
    if (!_android) return;
    unawaited(NfcForeground.instance.hold());
  }

  void _release() {
    if (!_android) return;
    unawaited(NfcForeground.instance.release());
  }

  bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Widget build(BuildContext context) => widget.child;
}
