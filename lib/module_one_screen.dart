import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'custom_keyboard.dart';
import 'globals.dart';
import 'help_screen.dart';
import 'teacher_setup_screen.dart';
import 'widgets/speech_queue_mixin.dart';
import 'widgets/on_screen_keyboard_mixin.dart';
import 'widgets/tts_status.dart';
import 'design_tokens.dart';

class ModuleOneScreen extends StatefulWidget {
  const ModuleOneScreen({super.key});

  @override
  State<ModuleOneScreen> createState() => _ModuleOneScreenState();
}

class _ModuleOneScreenState extends State<ModuleOneScreen>
    with SpeechQueueMixin, OnScreenKeyboardMixin, SingleTickerProviderStateMixin {
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
  String? _selectedThemeOverride;
  bool _hideBottomWord = false;
  bool _showWordListPanel = false;

  // Teacher chrome in the app bar (theme dropdown, keyboard toggle, voice
  // chip, Words panel, quiz-hide) sits in the child's peripheral vision.
  // It fades away 5s after the last interaction so the giant letter row
  // gets the whole visual field. Any tap on the peek button or the app
  // bar itself brings it back.
  bool _chromeExpanded = true;
  Timer? _chromeIdleTimer;
  static const Duration _chromeIdleDuration = Duration(seconds: 5);

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

  /// True when today's words are the built-in starters (CAT/DOG/BIRD)
  /// because no themes were scheduled, so the screen can say so.
  bool get _showingStarterWords {
    if (_selectedThemeOverride != null) return false;
    return getActiveThemesForDate(DateTime.now()).isEmpty;
  }

  @override
  void initState() {
    super.initState();
    
    final themes = getActiveThemesForDate(DateTime.now());
    for (var theme in themes) {
      incrementThemeAccessCount(theme);
    }
    
    _focusNode.requestFocus();
    _scheduleChromeIdle();
  }

  @override
  void dispose() {
    disposeSpeech();
    _wrongHintTimer?.cancel();
    _chromeIdleTimer?.cancel();
    _shake.dispose();
    _celebrate.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Starts / restarts the idle countdown. Called on entry and after any
  /// child-driven interaction so teacher chrome stays out of the way.
  void _scheduleChromeIdle() {
    _chromeIdleTimer?.cancel();
    _chromeIdleTimer = Timer(_chromeIdleDuration, () {
      if (!mounted) return;
      if (_chromeExpanded) setState(() => _chromeExpanded = false);
    });
  }

  void _revealChrome() {
    if (!_chromeExpanded) setState(() => _chromeExpanded = true);
    _scheduleChromeIdle();
  }

  void _flagWrongKey() {
    _shake.forward(from: 0);
    setState(() => _showWrongHint = true);
    _wrongHintTimer?.cancel();
    _wrongHintTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showWrongHint = false);
    });
  }

  void _triggerCelebration() {
    _celebrate.forward(from: 0);
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

    // The next expected letter in the word; anything else gets visible,
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
    // Real typing = chrome should stay collapsed and reset its countdown.
    if (_chromeExpanded) _scheduleChromeIdle();
    if (_typedText == targetWord) {
      _triggerCelebration();
    }

    enqueueLetterSpeech(letter);
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
          color: isMatch ? TyperColors.correct : TyperColors.incorrect,
          // Non-color cue so correctness doesn't rely on hue alone — thin underline keeps the giant letters airy.
          decoration: isMatch ? TextDecoration.underline : TextDecoration.lineThrough,
          decorationThickness: 1.4,
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
        child: Text("Only today's scheduled themes", style: TextStyle(color: Colors.black)),
      ),
      const DropdownMenuItem(
        value: '__ALL__',
        child: Text("Every theme on this profile", style: TextStyle(color: Colors.black)),
      )
    ];
    for (String theme in getAvailableThemes()) {
      final count = getWordsForTheme(theme).length;
      themeItems.add(DropdownMenuItem(
        value: theme,
        child: Text('$theme · $count words', style: const TextStyle(color: Colors.black)),
      ));
    }
    
    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      autofocus: true,
      child: Scaffold(
        backgroundColor: TyperColors.wordsBg.withValues(alpha: 0.14),
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
              const Text('Words ', style: TextStyle(fontSize: 24, color: Colors.black)),
              // One calm suffix style for every state — the app bar is not
              // the place for alarm colors (the caption below explains
              // starter words to whoever needs it).
              if (activeThemes.isNotEmpty && _selectedThemeOverride == null)
                Text('· ${activeThemes.length} themes, $activeWordsCount words', style: const TextStyle(fontSize: 18, color: TyperColors.inkSecondary))
              else if (_selectedThemeOverride != null)
                Text('· ${_selectedThemeOverride == '__ALL__' ? 'every theme' : _selectedThemeOverride}, ${_currentPracticeWords.length} words', style: const TextStyle(fontSize: 18, color: TyperColors.inkSecondary))
              else
                Text('· no themes scheduled today', style: const TextStyle(fontSize: 18, color: TyperColors.inkSecondary)),
            ],
          ),
          actions: [
            // Auto-hiding teacher chrome. Collapsed = one Tune icon that
            // brings everything back. Expanded = the full row.
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SizeTransition(
                  sizeFactor: anim,
                  axis: Axis.horizontal,
                  child: child,
                ),
              ),
              child: _chromeExpanded
                  ? Row(
                      key: const ValueKey('chrome-expanded'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
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
                              _scheduleChromeIdle();
                            },
                          ),
                        ),
                        buildKeyboardToggleButton(),
                        const VoiceStatusChip(),
                        TextButton.icon(
                          icon: Icon(Icons.list_alt, size: 22, color: _showWordListPanel ? TyperColors.speakBlue : Colors.black),
                          label: Text("Words", style: TextStyle(color: _showWordListPanel ? TyperColors.speakBlue : Colors.black, fontWeight: FontWeight.bold)),
                          onPressed: () {
                            setState(() => _showWordListPanel = !_showWordListPanel);
                            _focusNode.requestFocus();
                            _scheduleChromeIdle();
                          },
                          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                        ),
                        IconButton(
                          // Selection state = speakBlue per DESIGN.md, not
                          // semantic-green (which means "correct" here).
                          icon: Icon(_hideBottomWord ? Icons.visibility_off : Icons.visibility, size: 26, color: _hideBottomWord ? TyperColors.speakBlue : Colors.black),
                          tooltip: _hideBottomWord ? "Show word" : "Quiz: hide word",
                          onPressed: () {
                            setState(() => _hideBottomWord = !_hideBottomWord);
                            _focusNode.requestFocus();
                            _scheduleChromeIdle();
                          },
                        ),
                      ],
                    )
                  : const SizedBox.shrink(key: ValueKey('chrome-collapsed')),
            ),
            IconButton(
              icon: Icon(_chromeExpanded ? Icons.expand_less : Icons.tune, size: 26, color: TyperColors.inkSecondary),
              tooltip: _chromeExpanded ? "Hide teacher controls" : "Show teacher controls",
              onPressed: () {
                if (_chromeExpanded) {
                  setState(() => _chromeExpanded = false);
                  _chromeIdleTimer?.cancel();
                } else {
                  _revealChrome();
                }
                _focusNode.requestFocus();
              },
            ),
            const SizedBox(width: 16),
          ],
        ),
        // Banner overlays rather than inserts, so its appearance never
        // jolts the typing layout mid-word.
        body: BannerOverlay(
          child: Row(
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
                                      "That letter isn't next. Check the word below.",
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
                            speakWithGoogleCloud(targetWord);
                          },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _hideBottomWord ? "" : targetWord,
                              style: const TextStyle(
                                fontSize: 100, // Base size, FittedBox will scale it up
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            if (_showingStarterWords)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    "No themes scheduled today — practicing starter words",
                                    style: TextStyle(fontSize: 18, color: TyperColors.inkSecondary),
                                  ),
                                  const SizedBox(width: 12),
                                  TextButton.icon(
                                    icon: const Icon(Icons.calendar_today, size: 16),
                                    label: const Text('Schedule words'),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => const TeacherSetupScreen()),
                                      );
                                    },
                                  ),
                                ],
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
                    // Celebratory peak — thin underline keeps letters airy, this gives the triumph.
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
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _repeatWord,
                          icon: const Icon(Icons.repeat, size: 40),
                          label: const Text('REPEAT', style: TextStyle(fontSize: 32)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: TyperColors.correct,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _nextWord,
                          icon: const Icon(Icons.arrow_forward, size: 40),
                          label: const Text('NEXT', style: TextStyle(fontSize: 32)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: TyperColors.correctDeep,
                            foregroundColor: Colors.white,
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
                "Type the word, then press ENTER to hear it — press ENTER again for the next word",
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
      if (_showWordListPanel)
        Container(
          width: 300,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(left: BorderSide(color: TyperColors.hairline, width: 2)),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(-2, 0))],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16.0),
                color: TyperColors.selectionWash,
                child: const Row(
                  children: [
                    Icon(Icons.format_list_bulleted, color: TyperColors.speakBlue),
                    SizedBox(width: 8),
                    Text("Word List", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: TyperColors.speakBlue)),
                  ],
                ),
              ),
              SwitchListTile(
                title: const Text("Hide Word at Bottom"),
                value: _hideBottomWord,
                // Words screen owns the green accent; the Switch's active
                // thumb follows the activity ink, not phrases-purple.
                activeThumbColor: TyperColors.wordsInk,
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
                            color = TyperColors.correct;
                          } else {
                            color = TyperColors.incorrect;
                          }
                        }
                        spans.add(TextSpan(
                          text: word[i],
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            decoration: _typedText[i] == word[i]
                                ? TextDecoration.underline
                                : TextDecoration.lineThrough,
                            decorationThickness: 1.4,
                          ),
                        ));
                      }
                      if (_typedText.length > word.length) {
                        for (int i = word.length; i < _typedText.length; i++) {
                          spans.add(TextSpan(
                            text: _typedText[i],
                            style: const TextStyle(
                              color: TyperColors.destructive,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.lineThrough,
                              decorationThickness: 1.4,
                            ),
                          ));
                        }
                      }
                      // Merge with the ambient style so the chosen Reading
                      // Font applies (RichText ignores DefaultTextStyle).
                      titleWidget = RichText(
                        text: TextSpan(
                          style: DefaultTextStyle.of(context)
                              .style
                              .merge(const TextStyle(fontSize: 24)),
                          children: spans,
                        ),
                      );
                    } else {
                      titleWidget = Text(_currentPracticeWords[index], style: TextStyle(fontSize: 24, fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal, color: isCurrent ? TyperColors.speakBlue : Colors.black));
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
      ),
    );
  }
}
