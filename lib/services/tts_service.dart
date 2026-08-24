import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;

import 'profile_store.dart';

// --- GOOGLE CLOUD TTS SETTINGS ---
String currentGoogleApiKey = ''; // Held in memory only; never written to disk.
final AudioPlayer _audioPlayer = AudioPlayer();
final FlutterTts _flutterTts = FlutterTts();

enum TtsVoiceMode { cloud, free, local }

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

/// One-time reachability check so the voice chip tells the truth from app
/// start instead of showing "Offline" until the first utterance succeeds.
bool? _freeNaturalReachable;
int? _workingFreeProvider;

Future<bool> _probeFreeNaturalVoices() async {
  if (_freeNaturalReachable != null) return _freeNaturalReachable!;
  for (final provider in [0, 1]) {
    try {
      final response = await http
          .get(Uri.parse(_freeNaturalUrl(provider, 'ok')))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        _workingFreeProvider = provider;
        _freeNaturalReachable = true;
        debugPrint("Free natural voices: using provider $provider");
        return true;
      }
    } catch (e) {
      debugPrint("Free voice probe $provider failed: $e");
    }
  }
  _freeNaturalReachable = false;
  debugPrint("Free natural voices unreachable - falling back to built-in TTS");
  return false;
}

Future<bool> _tryFreeProvider(int provider, String text, int expectedRequestId) async {
  try {
    final url = Uri.parse(_freeNaturalUrl(provider, text));
    if (kIsWeb) {
      // The web player streams through an <audio> element, which loads
      // cross-origin media without CORS restrictions. BytesSource is NOT
      // supported by audioplayers' web implementation. Load failures here
      // surface asynchronously outside our control, so playback is
      // optimistic.
      if (expectedRequestId != _ttsRequestId) return true;
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(url.toString()));
      return true;
    }
    final response = await http.get(url).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200 || response.bodyBytes.isEmpty) return false;
    if (expectedRequestId != _ttsRequestId) return true; // superseded; drop it
    await _audioPlayer.stop();
    await _audioPlayer.play(BytesSource(response.bodyBytes));
    return true;
  } catch (e) {
    debugPrint("Free voice provider $provider failed: $e");
    return false;
  }
}

/// Tries the remembered working provider first, then the others.
Future<bool> _speakViaFreeNatural(String text, int expectedRequestId) async {
  if (_workingFreeProvider != null) {
    return _tryFreeProvider(_workingFreeProvider!, text, expectedRequestId);
  }
  for (final provider in [0, 1]) {
    if (await _tryFreeProvider(provider, text, expectedRequestId)) {
      _workingFreeProvider = provider;
      return true;
    }
  }
  return false;
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

Future<void> _applyWebVoice(String preference) async {
  if (!kIsWeb) return;
  try {
    if (_cachedWebVoices == null || _cachedWebVoices!.isEmpty) {
      final voices = await _flutterTts.getVoices;
      if (voices is List && voices.isNotEmpty) {
        _cachedWebVoices = {
          for (final v in voices)
            if (v is Map)
              "${v['name']}|${v['locale']}": Map<String, String>.from(v),
        };
      }
    }
    if (_cachedWebVoices == null || _cachedWebVoices!.isEmpty) return;

    const maleHints = ['male', 'guy', 'david', 'mark', 'james', 'george', 'ryan', 'daniel', 'alex'];
    const femaleHints = ['female', 'woman', 'zira', 'aria', 'jenny', 'michelle', 'susan', 'samantha', 'libby', 'sonia'];
    final hints = (preference == 'BOY' || preference == 'MAN') ? maleHints : femaleHints;

    String? bestName;
    String? bestLocale;
    var bestScore = -1;
    for (final v in _cachedWebVoices!.values) {
      final name = (v['name'] ?? '').toLowerCase();
      final locale = (v['locale'] ?? '').toLowerCase();
      if (!locale.startsWith('en')) continue;
      var score = 0;
      if (hints.any(name.contains)) score += 5;
      // Prefer higher-quality engine voices when present.
      if (name.contains('google') || name.contains('natural') || name.contains('online')) score += 2;
      if (locale == 'en-us') score += 1;
      if (score > bestScore) {
        bestScore = score;
        bestName = v['name'];
        bestLocale = v['locale'];
      }
    }
    if (bestName != null && bestLocale != null) {
      await _flutterTts.setVoice({'name': bestName, 'locale': bestLocale});
    }
  } catch (e) {
    debugPrint("Web voice selection failed: $e");
  }
}

Future<void> _speakWithLocalTts(String text, double localPitch) async {
  await _flutterTts.setLanguage("en-US");
  await _flutterTts.setSpeechRate(0.5);
  await _flutterTts.setPitch(localPitch);
  if (kIsWeb) await _applyWebVoice(currentProfile.voicePreference);
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
    await _flutterTts.stop();
  } catch (_) {}
}

/// Kicks off the free-voice reachability probe at app start so the voice
/// chip reflects reality before the first utterance.
Future<void> initVoiceStatus() async {
  unawaited(_probeThenSetInitialMode());
}

Future<void> _probeThenSetInitialMode() async {
  final reachable = await _probeFreeNaturalVoices();
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
    // Free natural voices first; the built-in engine is the last resort.
    // The startup probe makes the first utterance's decision (and the chip)
    // accurate even before this point.
    if (await _speakViaFreeNatural(text, currentRequestId)) {
      ttsVoiceMode.value = TtsVoiceMode.free;
      return;
    }
    _freeNaturalReachable = false;
    ttsVoiceMode.value = TtsVoiceMode.local;
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
      ttsVoiceMode.value = TtsVoiceMode.local;
      await _speakWithLocalTts(text, localPitch);
    }
  } catch (e) {
    // Network error (no internet). Free natural voices need the network
    // too, so this lands on the built-in engine.
    debugPrint("TTS Network Error: $e");
    ttsDegraded.value = true;
    ttsVoiceMode.value = TtsVoiceMode.local;
    await _speakWithLocalTts(text, localPitch);
  }
}
