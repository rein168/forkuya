import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;

import '../web_audio.dart';
import '../piper.dart';
import 'profile_store.dart';

// --- GOOGLE CLOUD TTS SETTINGS ---
String currentGoogleApiKey = ''; // Held in memory only; never written to disk.
final AudioPlayer _audioPlayer = AudioPlayer();
final FlutterTts _flutterTts = FlutterTts();

enum TtsVoiceMode { cloud, free, piper, local }

/// Deployment marker so we can confirm which build actually shipped to the PWA
/// (search for this string in the deployed main.dart.js).
const String kTtsBuildMarker = 'tts-azure-piper-2026-07';

/// Base URL of the self-hosted Azure Neural voice proxy (a free Cloudflare
/// Worker; see cloudflare-worker/). Empty means "not configured" — the app
/// then falls back to the device/browser voice. For quick testing without a
/// rebuild, append `?ttsproxy=<url>` to the app URL on web (handled below).
const String kDefaultFreeVoiceProxyUrl = '';

/// Resolves the proxy base: a `?ttsproxy=` query override on web wins (handy
/// for testing a freshly deployed Worker), otherwise the baked-in default.
String _freeVoiceProxyBase() {
  if (kIsWeb) {
    final override = Uri.base.queryParameters['ttsproxy'];
    if (override != null && override.trim().isNotEmpty) return override.trim();
  }
  return kDefaultFreeVoiceProxyUrl;
}

// Azure Neural voices per profile. Ana is a genuine child voice; there is no
// child-male neural voice, so BOY uses an adult male raised in pitch.
const Map<String, String> _azureVoices = {
  'BOY': 'en-US-GuyNeural',
  'GIRL': 'en-US-AnaNeural',
  'MAN': 'en-US-ChristopherNeural',
  'WOMAN': 'en-US-JennyNeural',
};
const Map<String, String> _azurePitch = {
  'BOY': '+18%',
  'GIRL': '+0%',
  'MAN': '+0%',
  'WOMAN': '+0%',
};

/// Speaks [text] through the Azure Neural proxy. Returns true only after audio
/// actually plays — the honest "Natural Voice" signal. Works on web (the proxy
/// sends CORS, so fetch → same-origin blob → play succeeds) and on native
/// (plain GET → bytes → audioplayers). Falls through when unconfigured or the
/// Worker is unreachable, so the app never goes silent.
/// Speaks [text] with the bundled offline Piper neural voice (web only).
/// Returns true only after audio actually plays. Loads a ~63 MB model on first
/// use, so it is only attempted when the teacher has opted into the offline
/// voice. Falls through silently on any failure.
String _getPiperVoiceId() {
  switch (currentProfile.voicePreference) {
    case 'BOY':
      return 'en_US-joe-medium';
    case 'MAN':
      return 'en_US-ryan-medium';
    case 'GIRL':
      return 'en_US-hfc_female-medium';
    case 'WOMAN':
    default:
      return 'en_US-amy-medium';
  }
}

Future<bool> _speakViaPiper(String text, int expectedRequestId) async {
  if (!kIsWeb || !getOfflineVoiceEnabled() || !piperSupported()) return false;
  piperSetVoice(_getPiperVoiceId());
  final blobUrl = await piperSpeak(text);
  if (blobUrl.isEmpty) return false;
  if (expectedRequestId != _ttsRequestId) return true; // superseded
  return await playManagedUrl(blobUrl);
}

Future<bool> _speakViaProxy(String text, int expectedRequestId) async {
  final base = _freeVoiceProxyBase();
  if (base.isEmpty) return false;
  final pref = currentProfile.voicePreference;
  final voice = _azureVoices[pref] ?? 'en-US-JennyNeural';
  final pitch = _azurePitch[pref] ?? '+0%';
  final sep = base.contains('?') ? '&' : '?';
  final url = '$base${sep}voice=$voice'
      '&rate=${Uri.encodeComponent('-8%')}'
      '&pitch=${Uri.encodeComponent(pitch)}'
      '&text=${Uri.encodeComponent(text)}';
  try {
    if (kIsWeb) {
      if (expectedRequestId != _ttsRequestId) return true; // superseded
      return await fetchAndPlayFreeAudio(url);
    }
    final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 12));
    if (resp.statusCode != 200 || resp.bodyBytes.isEmpty) {
      debugPrint('Azure proxy failed: HTTP ${resp.statusCode}');
      return false;
    }
    if (expectedRequestId != _ttsRequestId) return true; // superseded
    await _audioPlayer.stop();
    await _audioPlayer.play(BytesSource(resp.bodyBytes));
    return true;
  } catch (e) {
    debugPrint('Azure proxy error: $e');
    return false;
  }
}

/// Which voice produced the most recent audio, for UI status display.
final ValueNotifier<TtsVoiceMode> ttsVoiceMode = ValueNotifier(TtsVoiceMode.local);

// --- FREE NATURAL VOICES (no API key) ---
// Two key-less providers, tried in order, so a single blocked domain can't
// kill natural speech. Ivy and Justin are genuine child voices, so BOY and
// GIRL finally sound like kids.
const Map<String, String> _freeNaturalVoices = {
  'BOY': 'Justin',
  'GIRL': 'Ivy',
  'MAN': 'Matthew',
  'WOMAN': 'Joanna',
};

String _freeNaturalUrl(int provider, String text) {
  final voice = _freeNaturalVoices[currentProfile.voicePreference] ?? 'Joanna';
  switch (provider) {
    case 0:
      return 'https://api.streamelements.com/kappa/v2/speech'
          '?voice=$voice&text=${Uri.encodeComponent(text)}';
    default:
      // Google Translate's TTS voice — extremely reliable, no key.
      return 'https://translate.google.com/translate_tts'
          '?ie=UTF-8&client=tw-ob&tl=en&q=${Uri.encodeComponent(text)}';
  }
}

/// Native-only reachability cache (web decides per-gesture, see below).
bool? _freeNaturalReachable;
int? _workingFreeProvider;

/// NATIVE reachability probe. On Android/Windows there are no browser CORS or
/// hotlink restrictions, so a plain GET that returns audio bytes is a truthful
/// signal. On web this is never used — a cross-origin GET is CORS-blocked and
/// the media-element hotlink is rejected by the provider (Google returns a 404
/// HTML page to browser requests), so reachability there can only be decided by
/// actually playing inside a user gesture.
Future<bool> _verifyFreeProviderNative(int provider) async {
  try {
    final url = Uri.parse(_freeNaturalUrl(provider, 'ok'));
    final response = await http.get(url).timeout(const Duration(seconds: 8));
    return response.statusCode == 200 && response.bodyBytes.isNotEmpty;
  } catch (e) {
    debugPrint("Free voice probe $provider failed: $e");
    return false;
  }
}

Future<bool> _probeFreeNaturalVoicesNative() async {
  if (_freeNaturalReachable != null) return _freeNaturalReachable!;
  for (final provider in [0, 1]) {
    if (await _verifyFreeProviderNative(provider)) {
      _workingFreeProvider = provider;
      _freeNaturalReachable = true;
      return true;
    }
  }
  _freeNaturalReachable = false;
  debugPrint("Free natural voices unreachable - falling back to built-in TTS");
  return false;
}

/// Attempts a free HTTP TTS provider. Runs inside the SPEAK gesture so the web
/// path is allowed to play audio. Returns true only after audio actually plays
/// (honest "Natural Voice" signal); false lets the caller fall through.
Future<bool> _speakViaFreeNatural(String text, int expectedRequestId) async {
  if (kIsWeb) {
    // Fetch (CORS-permitting) → same-origin blob → play in-gesture. Google has
    // no CORS so its fetch fails cleanly and we move on; StreamElements works
    // when it is up. No silent "success" is ever reported.
    for (final provider in [0, 1]) {
      if (expectedRequestId != _ttsRequestId) return true; // superseded; drop it
      final url = _freeNaturalUrl(provider, text);
      if (await fetchAndPlayFreeAudio(url)) {
        _workingFreeProvider = provider;
        return true;
      }
    }
    return false;
  }
  // NATIVE: download the bytes and play them through audioplayers.
  if (!await _probeFreeNaturalVoicesNative()) return false;
  final url = Uri.parse(_freeNaturalUrl(_workingFreeProvider!, text));
  try {
    final response = await http.get(url).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200 || response.bodyBytes.isEmpty) return false;
    if (expectedRequestId != _ttsRequestId) return true; // superseded; drop it
    await _audioPlayer.stop();
    await _audioPlayer.play(BytesSource(response.bodyBytes));
    return true;
  } catch (e) {
    debugPrint("Free voice playback failed: $e");
    return false;
  }
}

/// True only when the Cloud voice was expected (enabled + key present) but a
/// request failed and we fell back to the offline voice. Drives the warning
/// banner; cleared by a successful Cloud request or manual dismissal.
final ValueNotifier<bool> ttsDegraded = ValueNotifier(false);

bool get _cloudConfigured => currentProfile.ttsEnabled && currentGoogleApiKey.isNotEmpty;

Future<void> setGoogleApiKey(String key) async {
  currentGoogleApiKey = key;
  // Intentionally NOT saving to SharedPreferences so it is forgotten when the app closes
}

int _ttsRequestId = 0;

// --- WEB VOICE SELECTION ---
// flutter_tts on web is backed by the browser's built-in speech synthesis.
// Browser voice names vary by OS and browser, so we match each profile's
// preference by name heuristics instead of hardcoding one voice. This is
// free, needs no API key, and works offline.
Map<String, Map<String, String>>? _cachedWebVoices;

/// A voice name that signals a modern, natural-sounding online/neural engine
/// (Edge "… Online (Natural)", Chrome "Google …"). These are free, need no key,
/// and are the real "natural voice" tier on the web.
bool _isNaturalVoiceName(String name) {
  final n = name.toLowerCase();
  return n.contains('natural') ||
      n.contains('online') ||
      n.contains('neural') ||
      n.contains('google') ||
      n.contains('multilingual');
}

/// Loads and caches the browser's speech-synthesis voice list.
Future<void> _ensureWebVoices() async {
  if (!kIsWeb) return;
  if (_cachedWebVoices != null && _cachedWebVoices!.isNotEmpty) return;
  try {
    final voices = await _flutterTts.getVoices;
    if (voices is List && voices.isNotEmpty) {
      _cachedWebVoices = {
        for (final v in voices)
          if (v is Map)
            "${v['name']}|${v['locale']}": Map<String, String>.from(v),
      };
    }
  } catch (e) {
    debugPrint("Web voice enumeration failed: $e");
  }
}

/// Selects the best web voice for [preference] and returns true if the chosen
/// voice is a genuine natural/online voice (so the caller can label the chip
/// honestly). Natural quality is weighted above exact gender: a natural voice
/// of the right-ish gender beats a robotic exact match for a child listener.
Future<bool> _applyWebVoice(String preference) async {
  if (!kIsWeb) return false;
  await _ensureWebVoices();
  if (_cachedWebVoices == null || _cachedWebVoices!.isEmpty) return false;
  try {
    const maleHints = ['male', 'guy', 'david', 'mark', 'james', 'george', 'ryan', 'daniel', 'alex', 'christopher', 'eric', 'brian', 'andrew'];
    const femaleHints = ['female', 'woman', 'zira', 'aria', 'jenny', 'michelle', 'susan', 'samantha', 'libby', 'sonia', 'ana', 'emma', 'ava'];
    final hints = (preference == 'BOY' || preference == 'MAN') ? maleHints : femaleHints;
    // "Ana" (Edge) is a child female voice; prefer it for GIRL.
    final childHint = preference == 'GIRL' ? 'ana' : (preference == 'BOY' ? 'ana' : null);

    String? bestName;
    String? bestLocale;
    var bestScore = -1;
    for (final v in _cachedWebVoices!.values) {
      final name = (v['name'] ?? '').toLowerCase();
      final locale = (v['locale'] ?? '').toLowerCase();
      if (!locale.startsWith('en')) continue;
      var score = 0;
      // Natural quality dominates so we don't pick a robotic exact-gender match
      // over a natural near-match.
      if (_isNaturalVoiceName(name)) score += 6;
      if (hints.any(name.contains)) score += 5;
      if (childHint != null && name.contains(childHint)) score += 3;
      if (locale == 'en-us') score += 1;
      if (score > bestScore) {
        bestScore = score;
        bestName = v['name'];
        bestLocale = v['locale'];
      }
    }
    if (bestName != null && bestLocale != null) {
      await _flutterTts.setVoice({'name': bestName, 'locale': bestLocale});
      return _isNaturalVoiceName(bestName);
    }
  } catch (e) {
    debugPrint("Web voice selection failed: $e");
  }
  return false;
}

/// Speaks through the device / browser speech engine. On web this is also the
/// free "natural voice" tier when the browser exposes an online/neural voice —
/// the chip is set to [TtsVoiceMode.free] only when such a voice is actually
/// selected, and [TtsVoiceMode.local] otherwise. Never claims natural on a
/// silent robotic fallback.
Future<void> _speakWithLocalTts(String text, double localPitch) async {
  var isNatural = false;
  if (kIsWeb) isNatural = await _applyWebVoice(currentProfile.voicePreference);
  ttsVoiceMode.value = isNatural ? TtsVoiceMode.free : TtsVoiceMode.local;
  await _flutterTts.setLanguage("en-US");
  await _flutterTts.setSpeechRate(0.5);
  await _flutterTts.setPitch(localPitch);
  await _flutterTts.speak(text);
}

/// Stops all speech immediately and invalidates in-flight requests. Called
/// when a typing screen is disposed so audio never outlives its surface.
Future<void> stopAllSpeech() async {
  _ttsRequestId++; // invalidate any pending cloud responses
  try {
    await _audioPlayer.stop();
  } catch (_) {}
  try {
    await stopManagedAudio(); // stop any web blob playback
  } catch (_) {}
  try {
    await _flutterTts.stop();
  } catch (_) {}
}

/// Prepares the voice status at app start.
///
/// On web the free-voice decision is deferred to the first SPEAK gesture: a
/// browser cannot verify a cross-origin audio URL without a gesture, and it
/// can't reach the HTTP providers at all (CORS + hotlink blocks). Declaring
/// "unreachable" at startup — as the old muted-preload probe did — was the bug
/// that forced everyone onto the robotic voice. So on web we only warm the
/// voice list and leave the chip on its honest default until a real utterance
/// proves what plays. On native the plain-GET probe is truthful, so we keep it.
Future<void> initVoiceStatus() async {
  debugPrint('TTS build marker: $kTtsBuildMarker');
  unawaited(_probeThenSetInitialMode());
}

/// Begins loading the offline Piper engine (web only). Called when the teacher
/// turns the offline voice on, so the model is ready before the first press.
void warmOfflineVoice() {
  if (kIsWeb && piperSupported()) {
    piperSetVoice(_getPiperVoiceId());
    piperWarm();
  }
}

Future<void> _probeThenSetInitialMode() async {
  if (kIsWeb) {
    await _ensureWebVoices();
    // Preload the offline engine so the first press isn't blocked by the model.
    if (getOfflineVoiceEnabled() && piperSupported()) {
      piperSetVoice(_getPiperVoiceId());
      piperWarm();
    }
    return;
  }
  final reachable = await _probeFreeNaturalVoicesNative();
  // Only set the initial mode if no utterance has already decided it.
  if (_ttsRequestId == 0) {
    ttsVoiceMode.value = reachable ? TtsVoiceMode.free : TtsVoiceMode.local;
  }
}

Future<void> speakWithGoogleCloud(String text) async {  if (text.trim().isEmpty) return;

  final int currentRequestId = ++_ttsRequestId;

  String voiceCode;
  double pitch = 0.0;
  double localPitch = 1.0;

  // Voice picks stay within Google Cloud's free monthly allowance (Neural2
  // shares one free tier), and the built-in offline voice is always free.
  // Pitches stay close to natural — extreme shifts sound synthetic.
  switch (currentProfile.voicePreference) {
    case 'BOY':
      voiceCode = 'en-US-Neural2-J'; // youthful male
      pitch = 2.0;
      localPitch = 1.3;
      break;
    case 'MAN':
      voiceCode = 'en-US-Neural2-D';
      pitch = -2.0;
      localPitch = 0.7;
      break;
    case 'GIRL':
      voiceCode = 'en-US-Neural2-F';
      pitch = 1.0;
      localPitch = 1.25;
      break;
    case 'WOMAN':
    default:
      voiceCode = 'en-US-Neural2-E';
      pitch = 0.0;
      localPitch = 1.0; // Normal
      break;
  }

  if (!_cloudConfigured) {
    // Offline Piper first when opted in (works with no internet); otherwise the
    // Azure Neural proxy (genuinely natural, incl. a child voice); then legacy
    // HTTP providers (native only in practice). Finally the device/browser
    // engine — _speakWithLocalTts sets the chip honestly (free vs local).
    if (await _speakViaPiper(text, currentRequestId)) {
      ttsVoiceMode.value = TtsVoiceMode.piper;
      return;
    }
    if (await _speakViaProxy(text, currentRequestId)) {
      ttsVoiceMode.value = TtsVoiceMode.free;
      return;
    }
    if (await _speakViaFreeNatural(text, currentRequestId)) {
      ttsVoiceMode.value = TtsVoiceMode.free;
      return;
    }
    await _speakWithLocalTts(text, localPitch);
    return;
  }

  final url = Uri.parse('https://texttospeech.googleapis.com/v1/text:synthesize');
  final payload = {
    'input': {'text': text},
    'voice': {'languageCode': 'en-US', 'name': voiceCode},
    'audioConfig': {'audioEncoding': 'MP3', 'pitch': pitch}
  };

  try {
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': currentGoogleApiKey
      },
      body: jsonEncode(payload)
    );
    if (currentRequestId != _ttsRequestId) return;

    if (response.statusCode == 200) {
      ttsVoiceMode.value = TtsVoiceMode.cloud;
      ttsDegraded.value = false;
      final audioBase64 = jsonDecode(response.body)['audioContent'];
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource('data:audio/mp3;base64,$audioBase64'));
    } else {
      // API Key might be invalid or quota exceeded. Try the free natural
      // voices before falling all the way back to the built-in engine.
      debugPrint("Google API Error: ${response.statusCode}");
      ttsDegraded.value = true;
      if (await _speakViaFreeNatural(text, currentRequestId)) {
        ttsVoiceMode.value = TtsVoiceMode.free;
        return;
      }
      await _speakWithLocalTts(text, localPitch);
    }
  } catch (e) {
    // Network error (no internet). Free natural voices need the network
    // too, so this lands on the built-in engine.
    debugPrint("TTS Network Error: $e");
    ttsDegraded.value = true;
    await _speakWithLocalTts(text, localPitch);
  }
}
