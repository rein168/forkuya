import 'package:flutter/material.dart';
import 'globals.dart';
import 'help_screen.dart';

class PhrasebookScreen extends StatefulWidget {
  const PhrasebookScreen({super.key});

  @override
  State<PhrasebookScreen> createState() => _PhrasebookScreenState();
}

class _PhrasebookScreenState extends State<PhrasebookScreen> {

  void _speakPhrase(String phrase) async {
    incrementPhraseAccessCount(phrase);
    await speakWithGoogleCloud(phrase.toLowerCase());
  }

  Widget _buildBigButton(String phrase) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.purple.shade900,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.purple.shade200, width: 3),
        ),
        elevation: 4,
      ),
      onPressed: () {
        _speakPhrase(phrase);
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.volume_up, size: 48, color: Colors.purple),
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
        backgroundColor: Colors.purple.shade50,
        foregroundColor: Colors.purple.shade900,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.purple.shade100, width: 2),
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
          const Icon(Icons.volume_up, size: 24, color: Colors.purple),
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

  @override
  Widget build(BuildContext context) {
    final allPhrases = List<String>.from(getActivePhrases());
    
    final topPhrases = allPhrases.where((p) => isTopPhrase(p)).toList();
    final otherPhrases = allPhrases.where((p) => !isTopPhrase(p)).toList();

    return Scaffold(
      backgroundColor: Colors.purple.shade50,
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
        title: const Text('Phrasebook'),
        backgroundColor: Colors.purple.shade200,
      ),
      body: allPhrases.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  "No active phrases saved yet!\nAsk your teacher to turn some on in the Word Setup screen.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 32, color: Colors.grey),
                ),
              ),
            )
          : Scrollbar(
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
                        "Other Phrases",
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.purple.shade900),
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
    );
  }
}
