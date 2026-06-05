import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'package:google_fonts/google_fonts.dart';
import 'custom_keyboard.dart';
import 'globals.dart';
import 'help_screen.dart';

class ModuleOneScreen extends StatefulWidget {
  const ModuleOneScreen({super.key});

  @override
  State<ModuleOneScreen> createState() => _ModuleOneScreenState();
}

class _ModuleOneScreenState extends State<ModuleOneScreen> {
  final FocusNode _focusNode = FocusNode();

  int _currentWordIndex = 0;
  String _typedText = "";
  bool _hasSpokenOnEnter = false;
  String? _selectedThemeOverride;
  bool _hideBottomWord = false;
  bool _showWordListPanel = false;

  final List<String> _speakQueue = [];
  bool _isSpeaking = false;

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

  List<String> get _currentPracticeWords {
    if (_selectedThemeOverride == '__ALL__') {
      List<String> allWords = [];
      for (String theme in getAvailableThemes()) {
        allWords.addAll(getWordsForTheme(theme));
      }
      return allWords.toSet().toList();
    }
    if (_selectedThemeOverride != null) {
      return getWordsForTheme(_selectedThemeOverride!);
    }
    return getWordsForDate(DateTime.now());
  }

  String get targetWord {
    final words = _currentPracticeWords;
    if (words.isEmpty) return "HELLO";
    if (_currentWordIndex >= words.length) {
      return words.last;
    }
    return words[_currentWordIndex];
  }

  bool get isCompleted => _typedText == targetWord;

  @override
  void initState() {
    super.initState();
    
    // We increment the access count for the themes that get loaded.
    final themes = getActiveThemesForDate(DateTime.now());
    for (var theme in themes) {
      incrementThemeAccessCount(theme);
    }
    
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

    // Force the user to delete their mistake before typing new letters
    if (!targetWord.startsWith(_typedText)) {
      return;
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
      } else if (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        _handleKeyPress('ENTER');
      }
    }
  }

  void _speakFullWord() {
    speakWithGoogleCloud(targetWord);
    incrementWordAccessCount(targetWord);
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
      final words = _currentPracticeWords;
      if (words.length > 1) {
        int newIndex;
        do {
          newIndex = Random().nextInt(words.length);
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
        _typedText[i],
        style: TextStyle(
          fontSize: 200,
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
    final activeThemes = getActiveThemesForDate(DateTime.now());
    final activeWordsCount = getWordsForDate(DateTime.now()).length;
    
    final List<DropdownMenuItem<String?>> themeItems = [
      const DropdownMenuItem(
        value: null,
        child: Text("All Scheduled Themes", style: TextStyle(color: Colors.black)),
      ),
      const DropdownMenuItem(
        value: '__ALL__',
        child: Text("ALL THEMES", style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold)),
      )
    ];
    for (String theme in getAvailableThemes()) {
      themeItems.add(DropdownMenuItem(
        value: theme,
        child: Text(theme, style: const TextStyle(color: Colors.black)),
      ));
    }
    
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
          title: Row(
            children: [
              const Text('Module 1: Words ', style: TextStyle(fontSize: 24, color: Colors.black)),
              if (activeThemes.isNotEmpty && _selectedThemeOverride == null)
                Text('(${activeThemes.length} Themes, $activeWordsCount Words)', style: GoogleFonts.fredoka(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.purple))
              else if (_selectedThemeOverride != null)
                Text('(${_selectedThemeOverride == '__ALL__' ? 'ALL THEMES' : _selectedThemeOverride}, ${_currentPracticeWords.length} Words)', style: GoogleFonts.fredoka(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue))
              else
                Text('(NO THEMES ACTIVE)', style: GoogleFonts.fredoka(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red)),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: DropdownButton<String?>(
                value: _selectedThemeOverride,
                dropdownColor: Colors.white,
                items: themeItems,
                onChanged: (String? newTheme) {
                  setState(() {
                    _selectedThemeOverride = newTheme;
                    _currentWordIndex = 0;
                    _typedText = "";
                  });
                  _focusNode.requestFocus();
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.list_alt, size: 32, color: Colors.black),
              tooltip: "Word List Panel",
              onPressed: () {
                setState(() {
                  _showWordListPanel = !_showWordListPanel;
                });
                _focusNode.requestFocus();
              },
            ),
            const SizedBox(width: 16),
          ],
        ),
        body: Row(
          children: [
            Expanded(
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
                            _hideBottomWord ? "" : targetWord,
                            style: const TextStyle(
                              fontSize: 100, // Base size, FittedBox will scale it up
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
            if (!isCompleted)
              Expanded(
                flex: 1,
                child: CustomKeyboard(onKeyPressed: _handleKeyPress),
              ),
          ],
        ),
      ),
      if (_showWordListPanel)
        Container(
          width: 300,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(left: BorderSide(color: Colors.grey.shade300, width: 2)),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(-2, 0))],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16.0),
                color: Colors.blue.shade50,
                child: const Row(
                  children: [
                    Icon(Icons.format_list_bulleted, color: Colors.blue),
                    SizedBox(width: 8),
                    Text("Word List", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue)),
                  ],
                ),
              ),
              SwitchListTile(
                title: const Text("Hide Word at Bottom"),
                value: _hideBottomWord,
                activeColor: Colors.purple,
                onChanged: (bool val) {
                  setState(() {
                    _hideBottomWord = val;
                  });
                  _focusNode.requestFocus();
                },
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: _currentPracticeWords.length,
                  itemBuilder: (context, index) {
                    final isCurrent = index == _currentWordIndex;
                    
                    Widget titleWidget;
                    if (isCurrent && _typedText.isNotEmpty) {
                      List<TextSpan> spans = [];
                      String word = _currentPracticeWords[index];
                      for (int i = 0; i < word.length; i++) {
                        Color color = Colors.black;
                        if (i < _typedText.length) {
                          if (_typedText[i] == word[i]) {
                            color = Colors.green;
                          } else {
                            color = Colors.red;
                          }
                        }
                        spans.add(TextSpan(text: word[i], style: TextStyle(color: color, fontWeight: FontWeight.bold)));
                      }
                      // Render any extra wrong letters typed at the end
                      if (_typedText.length > word.length) {
                        for (int i = word.length; i < _typedText.length; i++) {
                          spans.add(TextSpan(text: _typedText[i], style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)));
                        }
                      }
                      titleWidget = RichText(text: TextSpan(style: const TextStyle(fontSize: 24), children: spans));
                    } else {
                      titleWidget = Text(_currentPracticeWords[index], style: TextStyle(fontSize: 24, fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal, color: isCurrent ? Colors.blue : Colors.black));
                    }

                    return ListTile(
                      title: titleWidget,
                      onTap: () {
                        setState(() {
                          _currentWordIndex = index;
                          _typedText = "";
                          _hasSpokenOnEnter = false;
                        });
                        _focusNode.requestFocus();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
    ],
  ),
),
    );
  }
}
