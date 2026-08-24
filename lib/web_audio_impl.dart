import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Direct HTML audio bridge for the free natural voices. Media elements load
/// cross-origin URLs without CORS restrictions (unlike fetch/XHR), and their
/// error events let us verify reachability honestly instead of guessing.
web.HTMLAudioElement? _current;

/// Muted load test: resolves true when the browser can actually load the
/// audio, false on error or timeout. Used by the startup probe.
Future<bool> checkManagedUrl(String url) {
  final completer = Completer<bool>();
  final audio = web.HTMLAudioElement()
    ..src = url
    ..preload = 'auto'
    ..muted = true;
  Timer? timer;
  void finish(bool ok) {
    if (completer.isCompleted) return;
    timer?.cancel();
    audio.remove();
    completer.complete(ok);
  }

  timer = Timer(const Duration(seconds: 8), () => finish(false));
  audio.oncanplay = ((web.Event _) => finish(true)).toJS;
  audio.onerror = ((web.Event _) => finish(false)).toJS;
  web.document.body?.appendChild(audio);
  audio.load();
  return completer.future;
}

/// Plays [url] through a managed element, stopping any previous one.
Future<void> playManagedUrl(String url) async {
  await stopManagedAudio();
  final audio = web.HTMLAudioElement()
    ..src = url;
  web.document.body?.appendChild(audio);
  _current = audio;
  try {
    await audio.play().toDart;
  } catch (_) {
    // Autoplay policy rejections land here on the very first utterance if
    // the browser loses the gesture chain; later attempts succeed.
  }
}

Future<void> stopManagedAudio() async {
  final audio = _current;
  if (audio == null) return;
  _current = null;
  audio.pause();
  audio.remove();
}
