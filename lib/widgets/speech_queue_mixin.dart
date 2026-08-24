import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

import '../services/tts_service.dart';

/// Translates a hardware key event into the same key strings the on-screen
/// [CustomKeyboard] produces: a single character, 'DEL', or 'ENTER'.
/// Returns null for keys the typing screens don't handle.
/// Must stay in sync with CustomKeyboard's pages — every character a saved
/// phrase can contain must be typeable here and there.
String? keyEventToTyperKey(KeyEvent event) {
  if (event is! KeyDownEvent) return null;
  final String char = event.logicalKey.keyLabel;
  if (char.length == 1 && RegExp(r"[a-zA-Z0-9 ,.?!':;\-]").hasMatch(char)) {
    return char.toUpperCase();
  }
  if (event.logicalKey == LogicalKeyboardKey.space) {
    return ' ';
  }
  if (event.logicalKey == LogicalKeyboardKey.backspace) {
    return 'DEL';
  }
  if (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter) {
    return 'ENTER';
  }
  return null;
}

/// Shared letter-by-letter speech queue used by the three typing screens.
/// Letters are spoken one at a time with a short gap so fast typists don't
/// get overlapping audio.
mixin SpeechQueueMixin<T extends StatefulWidget> on State<T> {
  final List<String> _speakQueue = [];
  bool _isSpeaking = false;

  /// Queues [letter] to be spoken. Spaces are spoken as the word "space"
  /// when [speakSpaceAsWord] is true, otherwise skipped.
  void enqueueLetterSpeech(String letter, {bool speakSpaceAsWord = false}) {
    if (letter == ' ') {
      if (!speakSpaceAsWord) return;
      letter = 'space';
    }
    _speakQueue.add(letter);
    _processSpeechQueue();
  }

  /// Drops any letters still waiting to be spoken (e.g. because a whole
  /// word/phrase is about to be spoken instead).
  void clearSpeechQueue() {
    _speakQueue.clear();
  }

  /// Cancels pending letter speech and stops all audio. Call from the
  /// host screen's dispose() so speech never outlives its surface.
  void disposeSpeech() {
    _speakQueue.clear();
    stopAllSpeech();
  }

  Future<void> _processSpeechQueue() async {
    if (_isSpeaking) return;
    _isSpeaking = true;

    while (_speakQueue.isNotEmpty) {
      String nextLetter = _speakQueue.removeAt(0);
      await speakWithGoogleCloud(nextLetter.toUpperCase());
      await Future.delayed(const Duration(milliseconds: 400));
    }
    _isSpeaking = false;
  }
}
