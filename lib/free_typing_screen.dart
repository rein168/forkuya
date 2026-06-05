import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'custom_keyboard.dart';
import 'globals.dart';
import 'help_screen.dart';

class FreeTypingScreen extends StatefulWidget {
  const FreeTypingScreen({super.key});

  @override
  State<FreeTypingScreen> createState() => _FreeTypingScreenState();
}

class _FreeTypingScreenState extends State<FreeTypingScreen> {
  final FocusNode _focusNode = FocusNode();
  final ScrollController _listScrollController = ScrollController();

  final List<String> _speakQueue = [];
  bool _isSpeaking = false;

  Future<void> _processSpeechQueue() async {
    if (_isSpeaking) return;
    _isSpeaking = true;
    
    while (_speakQueue.isNotEmpty) {
      String nextLetter = _speakQueue.removeAt(0);
      await speakWithGoogleCloud(nextLetter.toUpperCase());
      // Add a small delay between letters if desired, or let the API network delay naturally space them out.
      await Future.delayed(const Duration(milliseconds: 400));
    }
    _isSpeaking = false;
  }

  List<String> _finalizedPhrases = [];
  String _typedText = "";
  String _currentWord = "";

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _listScrollController.dispose();
    super.dispose();
  }

  void _handleKeyPress(String letter) async {
    if (letter == 'DEL') {
      if (_typedText.isNotEmpty) {
        setState(() {
          _typedText = _typedText.substring(0, _typedText.length - 1);
          if (_currentWord.isNotEmpty) {
            _currentWord = _currentWord.substring(0, _currentWord.length - 1);
          }
        });
      }
      return;
    }

    if (letter == " ") {
      if (_currentWord.isNotEmpty) {
        speakWithGoogleCloud(_currentWord);
        _currentWord = "";
      }
    } else {
      _currentWord += letter;
    }

    if (letter == 'ENTER') {
      if (_typedText.trim().isNotEmpty) {
        final phrase = _typedText.trim();
        processFreeTypedSentence(phrase);
        _speakQueue.clear();
        speakWithGoogleCloud(phrase.toLowerCase()); // Automatically speak it!
        setState(() {
          _finalizedPhrases.add(phrase);
          _typedText = "";
          _currentWord = "";
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_listScrollController.hasClients) {
            _listScrollController.animateTo(
              _listScrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
      return;
    }

    setState(() {
      _typedText += letter;
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
      } else if (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        _handleKeyPress('ENTER');
      }
    }
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
          title: const Text('Free Typing'),
          centerTitle: false,
        ),
        body: Column(
          children: [
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    Center(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.volume_up, size: 40),
                        label: const Text("SPEAK", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
                        ),
                        onPressed: () async {
                          String textToSpeak = _typedText.trim();
                          
                          if (textToSpeak.isEmpty && _finalizedPhrases.isNotEmpty) {
                            textToSpeak = _finalizedPhrases.last;
                          }

                          if (textToSpeak.isNotEmpty) {
                            if (textToSpeak == _typedText.trim()) {
                              processFreeTypedSentence(textToSpeak);
                            }
                            _speakQueue.clear();
                            await speakWithGoogleCloud(textToSpeak.toLowerCase());
                            _focusNode.requestFocus();
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: FractionallySizedBox(
                        widthFactor: 0.6,
                        child: Divider(thickness: 4, color: Colors.grey.shade300),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Render Finalized Phrases (Smaller, Green)
                    if (_finalizedPhrases.isNotEmpty) ...[
                      Expanded(
                        child: Scrollbar(
                          controller: _listScrollController,
                          child: ListView.builder(
                            padding: const EdgeInsets.only(right: 24.0),
                            controller: _listScrollController,
                            reverse: false,
                            itemCount: _finalizedPhrases.length,
                            itemBuilder: (context, index) {
                              final isLatest = index == _finalizedPhrases.length - 1;
                              return Text(
                                _finalizedPhrases[index],
                                style: TextStyle(
                                  fontSize: isLatest ? 60 : 40,
                                  fontWeight: FontWeight.bold,
                                  color: isLatest ? Colors.green : Colors.green.shade300,
                                ),
                                textAlign: TextAlign.center,
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: FractionallySizedBox(
                          widthFactor: 0.6,
                          child: Divider(thickness: 4, color: Colors.grey.shade300),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    // Render Current Typing Text (Massive, Black)
                    Container(
                      constraints: const BoxConstraints(minHeight: 150),
                      alignment: Alignment.center,
                      child: Text(
                        _typedText,
                        style: const TextStyle(
                          fontSize: 120, // Massive text size
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: CustomKeyboard(onKeyPressed: _handleKeyPress),
            ),
          ],
        ),
      ),
    );
  }
}
