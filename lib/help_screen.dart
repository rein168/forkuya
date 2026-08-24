import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_markdown/flutter_markdown.dart';

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
              h1: styled(const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              h2: styled(const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              h3: styled(const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              p: styled(const TextStyle(fontSize: 18)),
              listBullet: styled(const TextStyle(fontSize: 18)),
            ),
          );
        },
      ),
    );
  }
}
