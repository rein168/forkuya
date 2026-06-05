import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'custom_keyboard.dart';
import 'globals.dart';
import 'help_screen.dart';

class ModuleTwoScreen extends StatefulWidget {
  const ModuleTwoScreen({super.key});

  @override
  State<ModuleTwoScreen> createState() => _ModuleTwoScreenState();
}

class _ModuleTwoScreenState extends State<ModuleTwoScreen> {
  final FocusNode _focusNode = FocusNode();

  int _currentWordIndex = 0;
  String _typedText = "";
  bool _hasSpokenOnEnter = false;

  final List<String> _speakQueue = [];
  bool _isSpeaking = false;

  Future<void> _processSpeechQueue() async {
    if (_isSpeaking) return;
    _isSpeaking = true;
    
    while (_speakQueue.isNotEmpty) {
      String nextLetter = _speakQueue.removeAt(0);
      if (nextLetter == ' ') nextLetter = 'space';
      await speakWithGoogleCloud(nextLetter.toUpperCase());
      await Future.delayed(const Duration(milliseconds: 400));
    }
    _isSpeaking = false;
  }

  String get targetWord {
    final phrases = getActivePhrases();
    if (phrases.isEmpty) return "HELLO WORLD";
    if (_currentWordIndex >= phrases.length) {
      return phrases.last;
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

  void _handleKeyPress(String letter) async {
    if (letter == 'ENTER') {
      if (_typedText.isNotEmpty && !_hasSpokenOnEnter) {
        _speakQueue.clear();
        _isSpeaking = false;
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

    // Module 2 specifically needs SPACE logic for phrases
    if (letter == 'SPACE') {
      letter = ' ';
    }

    setState(() {
      _typedText += letter;
      _hasSpokenOnEnter = false;
    });

    _speakQueue.add(letter);
    _processSpeechQueue();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      final String char = event.logicalKey.keyLabel;
      if (char.length == 1 && RegExp(r'[a-zA-Z ,.?\!]').hasMatch(char)) {
        _handleKeyPress(char.toUpperCase());
      } else if (event.logicalKey == LogicalKeyboardKey.backspace) {
        _handleKeyPress('DEL');
      } else if (event.logicalKey == LogicalKeyboardKey.space) {
        _handleKeyPress('SPACE');
      } else if (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        _handleKeyPress('ENTER');
      }
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
            if (!isCompleted)
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
