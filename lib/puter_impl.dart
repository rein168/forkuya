import 'dart:js_interop';
import 'package:flutter/foundation.dart';

@JS('window.__puterSpeak')
external JSPromise _puterSpeak(String text, String voice);

@JS('window.__puterStop')
external void _puterStop();

Future<bool> puterSpeak(String text, String voice) async {
  try {
    final result = await _puterSpeak(text, voice).toDart;
    return (result as JSBoolean).toDart;
  } catch (e) {
    debugPrint("Puter speak error: $e");
    return false;
  }
}

void puterStop() {
  try {
    _puterStop();
  } catch (e) {
    debugPrint("Puter stop error: $e");
  }
}

