import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

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
          return Markdown(
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
        },
      ),
    );
  }
}
