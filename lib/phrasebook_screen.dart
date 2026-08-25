import 'package:flutter/material.dart';
import 'globals.dart';
import 'help_screen.dart';
import 'teacher_setup_screen.dart';
import 'widgets/adult_gate.dart';
import 'widgets/teacher_route.dart';
import 'widgets/tts_status.dart';
import 'design_tokens.dart';

class PhrasebookScreen extends StatefulWidget {
  const PhrasebookScreen({super.key});

  @override
  State<PhrasebookScreen> createState() => _PhrasebookScreenState();
}

class _PhrasebookScreenState extends State<PhrasebookScreen> {
  @override
  void dispose() {
    // Phrases speak here too; audio must not outlive the surface.
    stopAllSpeech();
    super.dispose();
  }

  void _speakPhrase(String phrase) async {
    incrementPhraseAccessCount(phrase);
    await speakWithCloud(phrase.toLowerCase());
  }

  Widget _buildBigButton(String phrase) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: TyperColors.surfaceRaised,
        foregroundColor: TyperColors.phrasesInk,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: TyperColors.phrasesBorder, width: 3),
        ),
        elevation: 4,
      ),
      onPressed: () {
        _speakPhrase(phrase);
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.volume_up, size: 48, color: TyperColors.phrasesInk),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              phrase,
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallButton(String phrase) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: TyperColors.surfaceRaised,
        foregroundColor: TyperColors.phrasesInk,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: TyperColors.phrasesBorder, width: 2),
        ),
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      onPressed: () {
        _speakPhrase(phrase);
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.volume_up, size: 24, color: TyperColors.phrasesInk),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              phrase,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// A handful of speakable ghost phrases so a nonverbal child never
  /// lands in a silent room. Tapping any one still says it aloud.
  static const List<String> _starterGhosts = ['HELLO', 'YES', 'MORE'];

  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: TyperColors.phrasesWash,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: TyperColors.phrasesBorder, width: 2),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.chat_bubble_outline, size: 40, color: TyperColors.phrasesInk),
                  const SizedBox(height: 12),
                  const Text(
                    'Your phrases live here',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: TyperColors.phrasesInk),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Try one of these while your teacher adds more.',
                    style: TextStyle(fontSize: 16, color: TyperColors.inkSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Three tappable ghosts so the child has a voice immediately.
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.4,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: _starterGhosts.map(_buildBigButton).toList(),
          ),
          const SizedBox(height: 32),
          // The child cannot ask verbally, so give them the ask.
          Center(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.lock_outline, size: 22),
              label: const Text('Ask a grown-up', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                foregroundColor: TyperColors.speakBlue,
                side: const BorderSide(color: TyperColors.speakBlue, width: 2.5),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allPhrases = List<String>.from(getActivePhrases());
    
    final topPhrases = allPhrases.where((p) => isTopPhrase(p)).toList();
    final otherPhrases = allPhrases.where((p) => !isTopPhrase(p)).toList();

    return Scaffold(
      backgroundColor: TyperColors.phrasesWash,
      appBar: AppBar(
        leadingWidth: 100,
        leading: Row(
          children: [
            const BackButton(),
            IconButton(
              icon: const Icon(Icons.help_outline, size: 32),
              tooltip: 'User Manual',
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const HelpScreen(section: 'phrasebook')));
              },
            ),
          ],
        ),
        title: const Text('Phrasebook'),
        actions: [
          const VoiceStatusChip(),
          const SizedBox(width: 12),
        ],
      ),
      body: allPhrases.isEmpty
          ? BannerOverlay(child: _buildEmptyState(context))
          : BannerOverlay(
              child: Scrollbar(
              thumbVisibility: true,
              interactive: false, // Prevent hit test area from swallowing button taps
              thickness: 12.0,
              radius: const Radius.circular(8),
              child: CustomScrollView(
                slivers: [
                SliverPadding(
                  padding: const EdgeInsets.only(left: 16.0, right: 32.0, top: 16.0, bottom: 16.0),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 2.5,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildBigButton(topPhrases[index]),
                      childCount: topPhrases.length,
                    ),
                  ),
                ),
                if (otherPhrases.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        "More Phrases",
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: TyperColors.phrasesInk),
                      ),
                    ),
                  ),
                if (otherPhrases.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.only(left: 16.0, right: 32.0, bottom: 16.0),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4, // 4 smaller buttons per row
                        childAspectRatio: 2.0,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildSmallButton(otherPhrases[index]),
                        childCount: otherPhrases.length,
                      ),
                    ),
                  ),
                ],
              ),
            ),
      ),
    );
  }
}
