import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initGlobals();
  if (!kIsWeb) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }
  runApp(const TyperApp());
}

class TyperApp extends StatelessWidget {
  const TyperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Typer',
      theme: ThemeData(
        textTheme: GoogleFonts.fredokaTextTheme(
          Theme.of(context).textTheme,
        ),
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        scrollbarTheme: ScrollbarThemeData(
          thumbVisibility: MaterialStateProperty.all(true),
          trackVisibility: MaterialStateProperty.all(true),
          thumbColor: MaterialStateProperty.all(Colors.blue.shade300),
          trackColor: MaterialStateProperty.all(Colors.blue.shade50),
          thickness: MaterialStateProperty.all(16),
          radius: const Radius.circular(20),
          interactive: true,
        ),
      ),
      home: const ProfileSelectionScreen(),
      routes: {
        '/manual': (context) => const HelpScreen(),
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
        title: Text('Typer Main Menu - ${currentProfile.name}', style: GoogleFonts.fredoka(fontWeight: FontWeight.bold)),
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
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
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
      body: Center(
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
                backgroundColor: Colors.lightGreen.shade200,
                foregroundColor: Colors.green.shade900,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                fixedSize: const Size(400, 100),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
              child: const Text('Module 1: Words', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const ModuleTwoScreen()));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple.shade200,
                foregroundColor: Colors.purple.shade900,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                fixedSize: const Size(400, 100),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
              child: const Text('Module 2: Phrases', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
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
                backgroundColor: Colors.yellow.shade200,
                foregroundColor: Colors.orange.shade900,
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
            ElevatedButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const PhrasebookScreen()));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple.shade50,
                foregroundColor: Colors.purple.shade900,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                fixedSize: const Size(300, 60),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.purple.shade200, width: 2),
                ),
                elevation: 2,
              ),
              child: const Text('Phrasebook', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              icon: const Icon(Icons.settings, size: 24),
              label: const Text('Word Setup', style: TextStyle(fontSize: 18)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
      ),
    );
  }
}
