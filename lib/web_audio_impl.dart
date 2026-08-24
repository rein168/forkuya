import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Direct HTML audio bridge for free natural voices on the web.
///
/// Two hard truths shaped this design (verified empirically, see the probe
/// diagnostics below):
///  * Cross-origin `fetch`/XHR is blocked by CORS for the free TTS endpoints.
///  * A cross-origin `<audio src>` element is NOT blocked by CORS, but some
///    providers (Google Translate TTS) reject the browser's automatic
///    `Sec-Fetch-Site: cross-site` + `Referer` with a 404 HTML page, which the
///    media element then reports as MediaError code 4 ("format error").
///
/// So the only reliable browser path for a provider that *does* send permissive
/// CORS headers is: fetch the bytes → wrap them in a same-origin `blob:` URL →
/// play that through an `<audio>` element created inside the user gesture. A
/// `blob:` URL is same-origin, so it never hits CORS or hotlink protection and
/// its `canplay`/`error` events are trustworthy. Providers without CORS simply
/// fail the fetch and we fall through — honestly — to the next option.

web.HTMLAudioElement? _current;

/// Same-origin blob URLs for already-fetched utterances. The alphabet and the
/// common words are tiny and perfectly cacheable, so we never re-download.
final Map<String, String> _blobCache = {};

String _describeMediaError(web.HTMLAudioElement audio) {
  final err = audio.error;
  if (err == null) return 'no MediaError';
  return 'MediaError code=${err.code} message="${err.message}"';
}

/// Fetches [url] (CORS permitting), caches it as a same-origin blob, and plays
/// it through an audio element. Returns true only after playback has actually
/// begun — an honest signal for the "Natural Voice" chip. Must be called from
/// within a user gesture so the browser's autoplay policy allows `play()`.
Future<bool> fetchAndPlayFreeAudio(String url) async {
  try {
    var blobUrl = _blobCache[url];
    if (blobUrl == null) {
      final resp = await web.window.fetch(url.toJS).toDart;
      if (!resp.ok) {
        debugPrint('Free voice fetch failed: HTTP ${resp.status} for $url');
        return false;
      }
      final buffer = await resp.arrayBuffer().toDart;
      final blob = web.Blob(
        <JSAny>[buffer].toJS,
        web.BlobPropertyBag(type: 'audio/mpeg'),
      );
      if (blob.size == 0) {
        debugPrint('Free voice fetch returned empty body for $url');
        return false;
      }
      blobUrl = web.URL.createObjectURL(blob);
      _blobCache[url] = blobUrl;
    }
    return await _playUrlVerified(blobUrl);
  } catch (e) {
    // A CORS rejection (no Access-Control-Allow-Origin) lands here as a
    // "Failed to fetch" TypeError — expected for providers like Google that
    // don't expose CORS. We fall through to the next voice honestly.
    debugPrint('Free voice fetch/play error for $url: $e');
    return false;
  }
}

/// Plays a (same-origin) [url], resolving true once the element reaches
/// playback and false on error/timeout, surfacing the MediaError for the log.
Future<bool> _playUrlVerified(String url) async {
  await stopManagedAudio();
  final completer = Completer<bool>();
  final audio = web.HTMLAudioElement()..src = url;
  _current = audio;
  Timer? timer;
  void finish(bool ok) {
    if (completer.isCompleted) return;
    timer?.cancel();
    completer.complete(ok);
  }

  timer = Timer(const Duration(seconds: 8), () {
    debugPrint('Free voice playback timed out (readyState=${audio.readyState})');
    finish(false);
  });
  audio.onplaying = ((web.Event _) => finish(true)).toJS;
  audio.onended = ((web.Event _) => finish(true)).toJS;
  audio.onerror = ((web.Event _) {
    debugPrint('Free voice playback error: ${_describeMediaError(audio)}');
    finish(false);
  }).toJS;
  web.document.body?.appendChild(audio);
  try {
    await audio.play().toDart;
    // play() resolving is itself proof the browser accepted playback.
    finish(true);
  } catch (e) {
    debugPrint('Free voice play() rejected: $e');
    finish(false);
  }
  return completer.future;
}

/// Plays an already-usable [url] (e.g. a `blob:` URL from the Piper engine),
/// resolving true once playback begins. Must be called inside a user gesture.
Future<bool> playManagedUrl(String url) => _playUrlVerified(url);

Future<void> stopManagedAudio() async {
  final audio = _current;
  if (audio == null) return;
  _current = null;
  audio.pause();
  audio.remove();
}
