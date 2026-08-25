import 'dart:js_interop';
import 'package:flutter/foundation.dart';

@JS('window.__kokoroSpeak')
external JSPromise _kokoroSpeak(String text, String voiceId);

@JS('window.__kokoroStop')
external void _kokoroStop();

@JS('window.__kokoroWarm')
external JSPromise _kokoroWarm();

@JS('window.__kokoroProgress')
external double _kokoroProgress;

@JS('window.__kokoroState')
external String _kokoroState;

Future<bool> kokoroSpeak(String text, String voiceId) async {
  try {
    final result = await _kokoroSpeak(text, voiceId).toDart;
    return (result as JSBoolean).toDart;
  } catch (e) {
    debugPrint("Kokoro speak error: $e");
    return false;
  }
}

void kokoroStop() {
  try {
    _kokoroStop();
  } catch (e) {
    debugPrint("Kokoro stop error: $e");
  }
}

void kokoroWarm() {
  try {
    _kokoroWarm();
  } catch (e) {
    debugPrint("Kokoro warm error: $e");
  }
}

double kokoroProgress() {
  try {
    return _kokoroProgress;
  } catch (e) {
    return 0.0;
  }
}

String kokoroState() {
  try {
    return _kokoroState;
  } catch (e) {
    return "idle";
  }
}

