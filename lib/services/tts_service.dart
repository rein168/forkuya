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

Future<void> setGoogleApiKey(String key) async {
  currentGoogleApiKey = key;
  // Intentionally NOT saving to SharedPreferences so it is forgotten when the app closes
}

int _ttsRequestId = 0;

Future<void> _speakWithLocalTts(String text, double localPitch) async {
  await _flutterTts.setLanguage("en-US");
  await _flutterTts.setSpeechRate(0.5);
  await _flutterTts.setPitch(localPitch);
  await _flutterTts.speak(text);
}

Future<void> speakWithGoogleCloud(String text) async {
  if (text.trim().isEmpty) return;

  final int currentRequestId = ++_ttsRequestId;

  String voiceCode;
  double pitch = 0.0;
  double localPitch = 1.0;

  switch (currentProfile.voicePreference) {
    case 'BOY':
      voiceCode = 'en-US-Neural2-D';
      pitch = 6.0;
      localPitch = 2.0; // Very high
      break;
    case 'MAN':
      voiceCode = 'en-US-Neural2-D';
      pitch = -2.0;
      localPitch = 0.5; // Very low
      break;
    case 'GIRL':
      voiceCode = 'en-US-Neural2-F';
      pitch = 6.0;
      localPitch = 1.5; // High
      break;
    case 'WOMAN':
    default:
      voiceCode = 'en-US-Neural2-F';
      pitch = 0.0;
      localPitch = 1.0; // Normal
      break;
  }

  if (!currentProfile.ttsEnabled || currentGoogleApiKey.isEmpty) {
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
      final audioBase64 = jsonDecode(response.body)['audioContent'];
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource('data:audio/mp3;base64,$audioBase64'));
    } else {
      // API Key might be invalid or quota exceeded. Fallback to local TTS!
      debugPrint("Google API Error: ${response.statusCode}");
      await _speakWithLocalTts(text, localPitch);
    }
  } catch (e) {
    // Network error (no internet). Fallback to local TTS!
    debugPrint("TTS Network Error: $e");
    await _speakWithLocalTts(text, localPitch);
  }
}
