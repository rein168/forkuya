import 'package:flutter/material.dart';
import 'dart:math';
import 'custom_keyboard.dart';
import 'globals.dart';
import 'help_screen.dart';
import 'widgets/speech_queue_mixin.dart';
import 'widgets/on_screen_keyboard_mixin.dart';

class ModuleTwoScreen extends StatefulWidget {
  const ModuleTwoScreen({super.key});

  @override
  State<ModuleTwoScreen> createState() => _ModuleTwoScreenState();
}

class _ModuleTwoScreenState extends State<ModuleTwoScreen> with SpeechQueueMixin, OnScreenKeyboardMixin {
  final FocusNode _focusNode = FocusNode();

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

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _handleKeyPress(String letter) {
    if (letter == 'ENTER') {
      if (_typedText.isNotEmpty && !_hasSpokenOnEnter) {
        clearSpeechQueue();
        speakWithGoogleCloud(_typedText.toLowerCase());
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

    if (!targetWord.startsWith(_typedText)) {
      return;
    }

    setState(() {
      _typedText += letter;
      _hasSpokenOnEnter = false;
    });

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
    speakWithGoogleCloud(targetWord);
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
          color: isMatch ? Colors.green : Colors.red,
        ),
      ));
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: letters,
    );
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      autofocus: true,
      child: Scaffold(
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
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const HelpScreen()));
                },
              ),
            ],
          ),
          title: const Text('Module 2: Phrases', style: TextStyle(fontSize: 24, color: Colors.black)),
          backgroundColor: Colors.purple.shade200,
          actions: [
            buildKeyboardToggleButton(),
            const SizedBox(width: 16),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  Expanded(
                    flex: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: _buildTopSection(),
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
                            speakWithGoogleCloud(targetWord);
                          },
                          child: Text(
                            targetWord,
                            style: const TextStyle(
                              fontSize: 60, // Base size
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
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
                padding: const EdgeInsets.all(16.0),
                child: Wrap(
                  alignment: WrapAlignment.spaceEvenly,
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _speakFullWord,
                      icon: const Icon(Icons.volume_up, size: 40),
                      label: const Text('SPEAK', style: TextStyle(fontSize: 32)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _repeatWord,
                      icon: const Icon(Icons.repeat, size: 40),
                      label: const Text('REPEAT', style: TextStyle(fontSize: 32)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _nextWord,
                      icon: const Icon(Icons.arrow_forward, size: 40),
                      label: const Text('NEXT', style: TextStyle(fontSize: 32)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                      ),
                    ),
                  ],
                ),
              ),
            if (!isCompleted && isOnScreenKeyboardVisible)
              Expanded(
                flex: 1,
                child: CustomKeyboard(onKeyPressed: _handleKeyPress), // Assuming custom keyboard has a SPACE bar
              ),
          ],
        ),
      ),
    );
  }
}
