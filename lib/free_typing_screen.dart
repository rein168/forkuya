import 'package:flutter/material.dart';
import 'custom_keyboard.dart';
import 'globals.dart';
import 'help_screen.dart';
import 'widgets/speech_queue_mixin.dart';
import 'widgets/on_screen_keyboard_mixin.dart';
import 'widgets/tts_status.dart';
import 'design_tokens.dart';

class FreeTypingScreen extends StatefulWidget {
  const FreeTypingScreen({super.key});

  @override
  State<FreeTypingScreen> createState() => _FreeTypingScreenState();
}

class _FreeTypingScreenState extends State<FreeTypingScreen>
    with SpeechQueueMixin, OnScreenKeyboardMixin, WidgetsBindingObserver {
  final FocusNode _focusNode = FocusNode();
  final ScrollController _listScrollController = ScrollController();

  final List<String> _finalizedPhrases = [];
  String _typedText = "";

  // The word currently being typed (everything after the last space),
  // derived from _typedText so deletions can never desync it.
  String get _currentWord {
    final lastSpace = _typedText.lastIndexOf(' ');
    return lastSpace == -1 ? _typedText : _typedText.substring(lastSpace + 1);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Restore any unfinished message from the previous session.
    _typedText = getDraftText();
    _focusNode.requestFocus();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      flushDraftText();
    }
  }

  @override
  void dispose() {
    disposeSpeech();
    setDraftText(_typedText);
    flushDraftText();
    WidgetsBinding.instance.removeObserver(this);
    _focusNode.dispose();
    _listScrollController.dispose();
    super.dispose();
  }

  Future<bool> _confirmLeaveWithDraft() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Finish your message?"),
        content: const Text("Your typing is saved as a draft and will be here when you come back."),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _typedText = "";
                setDraftText("");
              });
              Navigator.pop(context, true);
            },
            child: const Text("Discard", style: TextStyle(color: TyperColors.destructive)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Keep Typing"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Save & Leave"),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  void _handleKeyPress(String letter) {
    if (letter == 'DEL') {
      if (_typedText.isNotEmpty) {
        setState(() {
          _typedText = _typedText.substring(0, _typedText.length - 1);
          setDraftText(_typedText);
        });
      }
      return;
    }

    if (letter == 'ENTER') {
      if (_typedText.trim().isNotEmpty) {
        final phrase = _typedText.trim();
        processFreeTypedSentence(phrase);
        clearSpeechQueue();
        speakWithGoogleCloud(phrase.toLowerCase()); // Automatically speak it!
        setState(() {
          _finalizedPhrases.add(phrase);
          _typedText = "";
          setDraftText("");
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

    // Speak the completed word when the student presses space.
    if (letter == " " && _currentWord.isNotEmpty) {
      speakWithGoogleCloud(_currentWord);
    }

    setState(() {
      _typedText += letter;
      setDraftText(_typedText);
    });

    enqueueLetterSpeech(letter);
  }

  void _handleKeyEvent(KeyEvent event) {
    final key = keyEventToTyperKey(event);
    if (key != null) {
      onPhysicalKeyUsed();
      _handleKeyPress(key);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _typedText.trim().isEmpty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmLeaveWithDraft()) {
          await flushDraftText();
          if (mounted) Navigator.pop(this.context);
        }
      },
      child: KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      autofocus: true,
      child: Scaffold(
        backgroundColor: TyperColors.freeTypingBg.withValues(alpha: 0.16),
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
          actions: [
            const VoiceStatusChip(),
            buildKeyboardToggleButton(),
            const SizedBox(width: 16),
          ],
        ),
        // Banner overlays rather than inserts, so its appearance never
        // jolts the typing layout mid-sentence.
        body: BannerOverlay(
          child: Column(
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
                          backgroundColor: TyperColors.speakBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
                        ),
                        onPressed: () async {
                          String textToSpeak = _typedText.trim();

                          if (textToSpeak.isEmpty && _finalizedPhrases.isNotEmpty) {
                            textToSpeak = _finalizedPhrases.last;
                          }

                          if (textToSpeak.isEmpty) {
                            // Nothing typed yet — tell the child instead of silence.
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Type something first, then press SPEAK!'),
                                duration: Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            _focusNode.requestFocus();
                            return;
                          }
                          if (textToSpeak == _typedText.trim()) {
                            processFreeTypedSentence(textToSpeak);
                          }
                          clearSpeechQueue();
                          await speakWithGoogleCloud(textToSpeak.toLowerCase());
                          _focusNode.requestFocus();
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: FractionallySizedBox(
                        widthFactor: 0.6,
                        child: Divider(thickness: 4, color: TyperColors.hairline),
                      ),
                    ),
                    const SizedBox(height: 16),
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
                                  fontSize: isLatest ? 56 : 34,
                                  fontWeight: FontWeight.bold,
                                  color: isLatest ? TyperColors.correct : TyperColors.correctDeep.withValues(alpha: 0.62),
                                  height: 1.1,
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
                          child: Divider(thickness: 4, color: TyperColors.hairline),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    Container(
                      constraints: const BoxConstraints(minHeight: 150),
                      alignment: Alignment.center,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
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
                    ),
                  ],
                ),
              ),
            ),
            // Shown regardless of input method — hardware-keyboard users
            // need the ENTER contract too.
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                "Press ENTER to hear your sentence",
                style: TextStyle(fontSize: 16, color: TyperColors.inkSecondary),
              ),
            ),
            if (isOnScreenKeyboardVisible)
              Expanded(
                flex: 1,
                child: CustomKeyboard(onKeyPressed: _handleKeyPress),
            ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
