import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Bridge to the offline Piper engine installed by web/piper/piper_loader.js
/// (window.__piperSpeak / __piperWarm / __piperState). Everything is guarded so
/// that if the loader hasn't evaluated yet — or the browser can't run it — the
/// calls fail soft and the TTS service falls through to the next voice.

bool piperSupported() => globalContext.has('__piperSpeak');

String piperState() {
  final v = globalContext['__piperState'];
  if (v.isA<JSString>()) return (v as JSString).toDart;
  return 'idle';
}

double piperProgress() {
  final v = globalContext['__piperProgress'];
  if (v.isA<JSNumber>()) return (v as JSNumber).toDartDouble;
  return 0;
}

/// Kicks off model + runtime loading ahead of the first utterance.
void piperWarm() {
  final fn = globalContext['__piperWarm'];
  if (fn.isA<JSFunction>()) {
    (fn as JSFunction).callAsFunction();
  }
}

/// Changes the active Piper voice.
void piperSetVoice(String voiceId) {
  final fn = globalContext['__piperSetVoice'];
  if (fn.isA<JSFunction>()) {
    (fn as JSFunction).callAsFunction(null, voiceId.toJS);
  }
}

/// Synthesizes [text] offline and returns a playable blob: URL, or '' on any
/// failure (loader missing, model load error, synthesis error).
Future<String> piperSpeak(String text) async {
  final fn = globalContext['__piperSpeak'];
  if (!fn.isA<JSFunction>()) return '';
  try {
    final result = (fn as JSFunction).callAsFunction(null, text.toJS);
    if (result.isA<JSPromise>()) {
      final url = await (result as JSPromise<JSString>).toDart;
      return url.toDart;
    }
    return '';
  } catch (_) {
    return '';
  }
}
