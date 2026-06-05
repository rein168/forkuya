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
            return Center(child: Text('Error loading manual: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Manual is empty.'));
          }
          return Markdown(
            data: snapshot.data!,
            selectable: true,
            styleSheet: MarkdownStyleSheet(
              h1: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blue),
              h2: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.purple),
              h3: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              p: const TextStyle(fontSize: 18),
              listBullet: const TextStyle(fontSize: 18),
            ),
          );
        },
      ),
    );
  }
}
