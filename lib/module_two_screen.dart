import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';
import 'custom_keyboard.dart';
import 'globals.dart';
import 'help_screen.dart';
import 'widgets/speech_queue_mixin.dart';
import 'widgets/on_screen_keyboard_mixin.dart';
import 'widgets/tts_status.dart';
import 'widgets/auto_hiding_chrome_mixin.dart';
import 'design_tokens.dart';

class ModuleTwoScreen extends StatefulWidget {
  const ModuleTwoScreen({super.key});

  @override
  State<ModuleTwoScreen> createState() => _ModuleTwoScreenState();
}

class _ModuleTwoScreenState extends State<ModuleTwoScreen>
    with SpeechQueueMixin, OnScreenKeyboardMixin, AutoHidingChromeMixin, SingleTickerProviderStateMixin {
  final FocusNode _focusNode = FocusNode();
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );
  late final AnimationController _celebrate = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  Timer? _wrongHintTimer;
  bool _showWrongHint = false;

  int _currentWordIndex = 0;
  String _typedText = "";
  bool _hasSpokenOnEnter = false;

  String get targetWord {
    final phrases = getActivePhrases();
    if (phrases.isEmpty) return "HELLO WORLD";
    if (_currentWordIndex >= phrases.length) {
      return phrases.last.toUpperCase();
    }
    return phrases[_currentWordIndex].toUpperCase();
  }

  bool get isCompleted => _typedText == targetWord;

  /// True when the practice phrase is the built-in fallback because no
  /// phrases are active, so the screen can say so.
  bool get _usingFallbackPhrase => getActivePhrases().isEmpty;

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
    scheduleChromeIdle();
  }

  @override
  void dispose() {
    disposeSpeech();
    _wrongHintTimer?.cancel();
    chromeIdleTimerCancel();
    _shake.dispose();
    _celebrate.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _flagWrongKey() {
    _shake.forward(from: 0);
    setState(() => _showWrongHint = true);
    _wrongHintTimer?.cancel();
    _wrongHintTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showWrongHint = false);
    });
  }

  void _triggerCelebration({int wordLength = 0}) {
    HapticFeedback.mediumImpact();
    final isLong = wordLength > 8;
    _celebrate.duration = Duration(milliseconds: isLong ? 950 : 700);
    _celebrate.forward(from: 0);
  }

  void _handleKeyPress(String letter) {
    if (letter == 'ENTER') {
      if (_typedText.isNotEmpty && !_hasSpokenOnEnter) {
        clearSpeechQueue();
        speakWithCloud(_typedText.toLowerCase());
        setState(() {
          _hasSpokenOnEnter = true;
        });
      } else {
        _nextWord();
      }
      return;
    }

    if (isCompleted) return;

    if (letter == 'DEL') {
      if (_typedText.isNotEmpty) {
        setState(() {
          _typedText = _typedText.substring(0, _typedText.length - 1);
          _hasSpokenOnEnter = false;
        });
      }
      return;
    }

    // The next expected letter in the phrase; anything else gets visible,
    // non-silent feedback instead of being swallowed.
    final expectedIndex = _typedText.length;
    final String? expectedLetter =
        expectedIndex < targetWord.length ? targetWord[expectedIndex] : null;
    if (expectedLetter == null || letter != expectedLetter) {
      _flagWrongKey();
      return;
    }

    setState(() {
      _typedText += letter;
      _hasSpokenOnEnter = false;
      _showWrongHint = false;
    });
    // Real typing keeps chrome collapsed and resets its countdown.
    noteChildActivity();
    if (_typedText == targetWord) {
      _triggerCelebration(wordLength: targetWord.length);
    }

    // Phrases contain spaces; speak them as the word "space" so the
    // student hears every key they press.
    enqueueLetterSpeech(letter, speakSpaceAsWord: true);
  }

  void _handleKeyEvent(KeyEvent event) {
    final key = keyEventToTyperKey(event);
    if (key != null) {
      onPhysicalKeyUsed();
      _handleKeyPress(key);
    }
  }

  void _speakFullWord() {
    speakWithCloud(targetWord);
  }

  void _repeatWord() {
    setState(() {
      _typedText = "";
      _hasSpokenOnEnter = false;
    });
    _focusNode.requestFocus();
  }

  void _nextWord() {
    setState(() {
      final phrases = getActivePhrases();
      if (phrases.length > 1) {
        int newIndex;
        do {
          newIndex = Random().nextInt(phrases.length);
        } while (newIndex == _currentWordIndex);
        _currentWordIndex = newIndex;
      }
      _typedText = "";
      _hasSpokenOnEnter = false;
    });
    _focusNode.requestFocus();
  }

  Widget _buildTopSection() {
    List<Widget> letters = [];
    for (int i = 0; i < _typedText.length; i++) {
      bool isMatch = i < targetWord.length && _typedText[i] == targetWord[i];
      letters.add(Text(
        _typedText[i] == ' ' ? ' ' : _typedText[i], // Render space cleanly
        style: TextStyle(
          fontSize: 100, // Slightly smaller than Mod 1 to fit phrases
          fontWeight: FontWeight.bold,
          color: isMatch ? TyperColors.correct : TyperColors.incorrect,
          // Non-color cue so correctness doesn't rely on hue alone — thin keeps it airy.
          decoration: isMatch ? TextDecoration.underline : TextDecoration.lineThrough,
          decorationThickness: 1.4,
        ),
      ));
    }
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: letters);
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      autofocus: true,
      child: Scaffold(
        backgroundColor: TyperColors.phrasesWash,
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          leadingWidth: 100,
          leading: Row(
            children: [
              const BackButton(),
              IconButton(
                icon: const Icon(Icons.help_outline, size: 32),
                tooltip: 'User Manual',
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const HelpScreen(section: 'sentences')));
                },
              ),
            ],
          ),
          title: const Text('Sentences', style: TextStyle(fontSize: 24, color: TyperColors.ink)),
          actions: buildChromeActions([
            buildKeyboardToggleButton(),
            const VoiceStatusChip(),
          ]),
        ),
        // Banner overlays rather than inserts, so its appearance never
        // jolts the typing layout mid-phrase.
        body: BannerOverlay(
          child: Column(
            children: [
              Expanded(
                flex: 2,
              child: Column(
                children: [
                  Expanded(
                    flex: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.contain,
                              child: AnimatedBuilder(
                                animation: _shake,
                                builder: (context, child) {
                                  final dx = sin(_shake.value * pi * 4) * 8 * (1 - _shake.value);
                                  return Transform.translate(offset: Offset(dx, 0), child: child);
                                },
                                child: _buildTopSection(),
                              ),
                            ),
                          ),
                          // Reserved slot: keeps the letter row from
                          // rescaling when the hint appears or disappears.
                          SizedBox(
                            height: 32,
                            child: _showWrongHint
                                ? Semantics(
                                    liveRegion: true,
                                    child: const Text(
                                      "That letter isn't next. Check the phrase below.",
                                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: TyperColors.incorrect),
                                    ),
                                  )
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(thickness: 4, height: 4),
                  Expanded(
                    flex: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: GestureDetector(
                          onTap: () {
                            speakWithCloud(targetWord);
                          },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              targetWord,
                              style: const TextStyle(
                                fontSize: 60, // Base size
                                fontWeight: FontWeight.bold,
                                color: TyperColors.ink,
                              ),
                            ),
                            if (_usingFallbackPhrase)
                              const Text(
                                "No active phrases yet — ask your teacher to turn some on",
                                style: TextStyle(fontSize: 18, color: TyperColors.inkSecondary),
                              ),
                          ],
                        ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (isCompleted)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  children: [
                    AnimatedBuilder(
                      animation: _celebrate,
                      builder: (context, child) {
                        final t = Curves.elasticOut.transform(_celebrate.value.clamp(0.0, 1.0));
                        return Transform.scale(
                          scale: 0.88 + t * 0.12,
                          child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: TyperColors.correct.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: TyperColors.correct.withValues(alpha: 0.22), width: 1.2),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.celebration, color: TyperColors.correct, size: 26),
                            SizedBox(width: 10),
                            Text("Wonderful! You did it!", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: TyperColors.correct)),
                            SizedBox(width: 10),
                            Icon(Icons.star_rounded, color: TyperColors.celebrateStar, size: 24),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      alignment: WrapAlignment.spaceEvenly,
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _speakFullWord,
                          icon: const Icon(Icons.volume_up, size: 40),
                          label: const Text('SPEAK', style: TextStyle(fontSize: 32)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: TyperColors.speakBlue,
                            foregroundColor: TyperColors.surfaceRaised,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _repeatWord,
                          icon: const Icon(Icons.repeat, size: 40),
                          label: const Text('REPEAT', style: TextStyle(fontSize: 32)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: TyperColors.correct,
                            foregroundColor: TyperColors.surfaceRaised,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _nextWord,
                          icon: const Icon(Icons.arrow_forward, size: 40),
                          label: const Text('NEXT', style: TextStyle(fontSize: 32)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: TyperColors.correctDeep,
                            foregroundColor: TyperColors.surfaceRaised,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            // Shown regardless of input method — hardware-keyboard users
            // need the ENTER contract too.
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                "Type the phrase, then press ENTER to hear it — press ENTER again for the next phrase",
                style: TextStyle(fontSize: 16, color: TyperColors.inkSecondary),
              ),
            ),
            if (!isCompleted && isOnScreenKeyboardVisible)
              Expanded(
                flex: 1,
                child: CustomKeyboard(onKeyPressed: _handleKeyPress),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

