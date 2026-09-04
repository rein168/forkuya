import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'module_one_screen.dart';
import 'teacher_setup_screen.dart';
import 'free_typing_screen.dart';
import 'globals.dart';
import 'settings_screen.dart';
import 'module_two_screen.dart';
import 'phrasebook_screen.dart';
import 'profile_selection_screen.dart';
import 'help_screen.dart';
import 'widgets/adult_gate.dart';
import 'widgets/save_status.dart';
import 'widgets/teacher_route.dart';
import 'package:url_launcher/url_launcher.dart';
import 'design_tokens.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initGlobals();
  // Probe free-voice reachability so the voice chip is truthful at startup,
  // and warm Piper if enabled (now ON by default).
  unawaited(initVoiceStatus());
  if (kIsWeb && getOfflineVoiceEnabled()) {
    // fire-and-forget; piper_impl guards if unsupported
    try { warmOfflineVoice(); } catch (_) {}
  }
  if (!kIsWeb) {
    // Orientation is now unlocked for all devices to support adaptivity, multitasking, and foldables.
  }
  runApp(const TyperApp());
}

class TyperApp extends StatelessWidget {
  const TyperApp({super.key});

  static const Map<String, TextTheme Function(TextTheme)> _fontFactories = {
    'Fredoka': GoogleFonts.fredokaTextTheme,
    'Lexend': GoogleFonts.lexendTextTheme,
    'Andika': GoogleFonts.andikaTextTheme,
  };

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: fontPreferenceNotifier,
      builder: (context, font, _) {
        final applyFont = _fontFactories[font] ?? GoogleFonts.fredokaTextTheme;
        return MaterialApp(
          title: 'Typer',
          theme: ThemeData(
            textTheme: applyFont(ThemeData.light().textTheme),
            colorScheme: ColorScheme.fromSeed(seedColor: TyperColors.speakBlue),
        useMaterial3: true,
        // One app-bar treatment everywhere; activity identity lives in
        // content accents, not per-screen chrome.
        appBarTheme: const AppBarTheme(
          backgroundColor: TyperColors.surfaceRaised,
          foregroundColor: TyperColors.ink,
          elevation: 0,
        ),
        scrollbarTheme: ScrollbarThemeData(
          thumbVisibility: WidgetStateProperty.all(true),
          trackVisibility: WidgetStateProperty.all(true),
          thumbColor: WidgetStateProperty.all(TyperColors.scrollThumb),
          trackColor: WidgetStateProperty.all(TyperColors.selectionWash),
          thickness: WidgetStateProperty.all(16),
          radius: const Radius.circular(20),
          interactive: true,
        ),
      ),
      home: const ProfileSelectionScreen(),
      routes: {
        '/manual': (context) => const HelpScreen(),
      },
        );
      },
    );
  }
}

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Typer Main Menu - ${currentProfile.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.switch_account, size: 32),
            tooltip: 'Switch Profile',
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const ProfileSelectionScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings, size: 32),
            tooltip: 'Settings',
            onPressed: () async {
              if (!await requireAdultGate(context, reason: 'Settings is for teachers and parents.')) return;
              if (!context.mounted) return;
              Navigator.push(
                context,
                TeacherRoute(builder: (context) => const SettingsScreen(), label: 'Passing to Settings…'),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.help_outline, size: 32),
            tooltip: 'User Manual',
            onPressed: () async {
              if (kIsWeb) {
                final url = Uri.parse('${Uri.base.toString().split('#')[0]}#/manual');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
                  return;
                }
              }
              if (context.mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const HelpScreen()),
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const SaveFailedBanner(),
          Expanded(
            child: Center(
              child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ModuleOneScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: TyperColors.wordsBg,
                foregroundColor: TyperColors.wordsInk,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                fixedSize: const Size(400, 100),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
              child: const Text('Words', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const ModuleTwoScreen()));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: TyperColors.phrasesBg,
                foregroundColor: TyperColors.phrasesInk,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                fixedSize: const Size(400, 100),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
              child: const Text('Sentences', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FreeTypingScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: TyperColors.freeTypingBg,
                foregroundColor: TyperColors.warningInk,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                fixedSize: const Size(400, 100),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
              child: const Text('Free Typing', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
            // Phrasebook is the child's one-tap voice — the teacher-built
            // phrases they can say NOW. It sits at the same visual weight as
            // Words/Sentences/Free Typing because it plays the same role: an
            // activity the child chooses. Outlined (wash + phrases border)
            // rather than filled purple so it reads as "my phrases" instead
            // of "Sentences practice" at a glance.
            ElevatedButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const PhrasebookScreen()));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: TyperColors.phrasesWash,
                foregroundColor: TyperColors.phrasesInk,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                fixedSize: const Size(400, 100),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: TyperColors.phrasesBorder, width: 3),
                ),
                elevation: 4,
              ),
              child: const Text('Phrasebook', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              icon: const Icon(Icons.settings, size: 24),
              label: const Text('Words & Phrases', style: TextStyle(fontSize: 18)),
              style: ElevatedButton.styleFrom(
                backgroundColor: TyperColors.warningInk,
                foregroundColor: TyperColors.surfaceRaised,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () async {
                if (!await requireAdultGate(context, reason: 'Word Setup is for teachers and parents.')) return;
                if (!context.mounted) return;
                Navigator.push(
                  context,
                  TeacherRoute(builder: (context) => const TeacherSetupScreen(), label: 'Passing to Word Setup…'),
                );
              },
            ),
            const SizedBox(height: 24),
            Builder(
              builder: (context) {
                final todayThemes = getActiveThemesForDate(DateTime.now());
                final todayWords = getWordsForDate(DateTime.now());
                final isStarter = todayThemes.isEmpty;
                // Preview in lowercase to match the child-facing surfaces
                // (Words, Sentences, Phrasebook all show lowercase now).
                final preview = todayWords.take(6).map((w) => w.toLowerCase()).join(', ') + (todayWords.length > 6 ? '…' : '');
                return Container(
                  constraints: const BoxConstraints(maxWidth: 520),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: TyperColors.surfaceRaised,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: TyperColors.hairline),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(isStarter ? Icons.lightbulb_outline : Icons.calendar_today, size: 18, color: TyperColors.inkSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isStarter
                              ? 'Today: starter words • $preview'
                              : 'Today: ${todayThemes.join(', ')} • $preview',
                          style: const TextStyle(fontSize: 14, color: TyperColors.inkSecondary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      if (isStarter)
                        TextButton.icon(
                          icon: const Icon(Icons.calendar_today, size: 14),
                          label: const Text('Schedule words', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            foregroundColor: TyperColors.speakBlue,
                          ),
                          onPressed: () async {
                            if (!await requireAdultGate(context, reason: 'Scheduling words is for teachers and parents.')) return;
                            if (!context.mounted) return;
                            Navigator.push(
                              context,
                              TeacherRoute(builder: (context) => const TeacherSetupScreen(), label: 'Passing to Word Setup…'),
                            );
                          },
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
            ),
          ],
        ),
    );
  }
}
