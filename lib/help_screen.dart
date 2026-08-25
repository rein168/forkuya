import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

class HelpScreen extends StatelessWidget {
  final String? section;
  const HelpScreen({super.key, this.section});

  String _tipFor(String s) {
    switch (s) {
      case 'words':
        return 'Tip for Words: Type the big letters, watch for the gentle shake if a letter isn’t next, and press ENTER to hear it. Try the Words list and Quiz hide to practice by ear.';
      case 'sentences':
        return 'Tip for Sentences: Type the full phrase including spaces. The 123+ key reveals numbers and symbols. ENTER speaks, ENTER again moves on.';
      case 'free':
        return 'Tip for Free Typing: This is your talk space. SPACE speaks the word you just finished, ENTER speaks the whole idea. Your draft is saved automatically.';
      case 'phrasebook':
        return 'Tip for Phrasebook: Tap any phrase to hear it. Star your favorites — they appear bigger at the top.';
      case 'teacher':
        return 'Tip for Teachers: Create a theme → add words → drag it to a day. Use Other Profiles to import from another student.';
      case 'settings':
        return 'Tip for Settings: Choose a voice, pick a reading font, and export a student’s profile to share with another device.';
      case 'profiles':
        return 'Tip for Profiles: Each student has their own words and progress. Tap a card to start, or use the trash icon to delete.';
      default:
        return '';
    }
  }

  Future<String> _loadManual() async {
    return await rootBundle.loadString('assets/typer_user_manual.md');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Manual'),
      ),
      body: FutureBuilder<String>(
        future: _loadManual(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            debugPrint("Manual load failed: ${snapshot.error}");
            return const Center(
              child: Text(
                'The manual could not be loaded. Try reinstalling the app.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Manual is empty.'));
          }
          // Inherit the app's chosen Reading Font instead of Roboto.
          final font = DefaultTextStyle.of(context).style.fontFamily;
          TextStyle styled(TextStyle s) => s.copyWith(fontFamily: font);
          final markdown = Markdown(
            data: snapshot.data!,
            selectable: true,
            styleSheet: MarkdownStyleSheet(
              h1: styled(const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, height: 1.2)),
              h1Padding: const EdgeInsets.only(top: 28, bottom: 10),
              h2: styled(const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, height: 1.3)),
              h2Padding: const EdgeInsets.only(top: 22, bottom: 8),
              h3: styled(const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, height: 1.3)),
              h3Padding: const EdgeInsets.only(top: 16, bottom: 6),
              p: styled(const TextStyle(fontSize: 16, height: 1.5)),
              pPadding: const EdgeInsets.only(bottom: 10),
              listBullet: styled(const TextStyle(fontSize: 16, height: 1.5)),
              listBulletPadding: const EdgeInsets.only(bottom: 6),
            ),
          );
          if (section == null || section!.isEmpty) return markdown;
          final tip = _tipFor(section!);
          if (tip.isEmpty) return markdown;
          return Column(
            children: [
              Container(
                width: double.infinity,
                color: const Color(0xFFE3F2FD),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline, size: 20, color: Color(0xFF1976D2)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(tip, style: const TextStyle(fontSize: 14, color: Color(0xFF0D47A1), height: 1.4))),
                  ],
                ),
              ),
              Expanded(child: markdown),
            ],
          );
        },
      ),
    );
  }
}
