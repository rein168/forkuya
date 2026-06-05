import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'help_screen.dart';
import 'updater.dart';
import 'globals.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late String _selectedVoice;
  late bool _ttsEnabled;
  String _appVersion = "Loading...";
  final TextEditingController _apiKeyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedVoice = getVoicePreference();
    _ttsEnabled = getTtsEnabled();
    _apiKeyController.text = currentGoogleApiKey;
    _loadVersion();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = '${info.version}+${info.buildNumber}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _appVersion = 'Unknown';
        });
      }
    }
  }

  void _testVoice() {
    String intro = "Hello! This is how I sound.";
    if (_selectedVoice == "BOY") intro = "Hello! I am a boy, this is how I sound.";
    if (_selectedVoice == "GIRL") intro = "Hello! I am a girl, this is how I sound.";
    if (_selectedVoice == "MAN") intro = "Hello! I am a man, this is how I sound.";
    if (_selectedVoice == "WOMAN") intro = "Hello! I am a woman, this is how I sound.";
    speakWithGoogleCloud(intro);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Voice Profile",
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const SizedBox(height: 16),
            const Text(
              "Select a Voice Profile. This app uses ultra-realistic Google Cloud Neural Voices to communicate.",
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            Center(
              child: SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 'BOY', label: Text('BOY', style: TextStyle(fontSize: 24))),
                  ButtonSegment(value: 'GIRL', label: Text('GIRL', style: TextStyle(fontSize: 24))),
                  ButtonSegment(value: 'MAN', label: Text('MAN', style: TextStyle(fontSize: 24))),
                  ButtonSegment(value: 'WOMAN', label: Text('WOMAN', style: TextStyle(fontSize: 24))),
                ],
                selected: {_selectedVoice},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() {
                    _selectedVoice = newSelection.first;
                    setVoicePreference(_selectedVoice);
                  });
                  _testVoice();
                },
              ),
            ),
            const SizedBox(height: 48),
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.record_voice_over, size: 32),
                label: const Text('TEST VOICE', style: TextStyle(fontSize: 24)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                onPressed: _testVoice,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: SwitchListTile(
                    title: const Text("Enable Ultra-Realistic AI Voices", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    subtitle: const Text(
                      "Google charges a small fee for every word spoken using their ultra-realistic cloud voices.\nTo help keep this app completely free for all students, please consider donating!", 
                      style: TextStyle(fontSize: 16)
                    ),
                    value: _ttsEnabled,
                    activeColor: Colors.purple,
                    onChanged: (bool value) {
                      setState(() {
                        _ttsEnabled = value;
                        setTtsEnabled(value);
                      });
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 16.0, left: 16.0),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.local_cafe, color: Colors.orange, size: 32),
                    label: const Text('Buy me a coffee!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                      backgroundColor: Colors.orange.shade50,
                      foregroundColor: Colors.orange.shade900,
                      elevation: 4,
                      side: BorderSide(color: Colors.orange.shade200, width: 2),
                    ),
                    onPressed: () async {
                      final url = Uri.parse('https://github.com/sponsors/'); // Placeholder URL
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url);
                      }
                    },
                  ),
                ),
              ],
            ),
            if (_ttsEnabled)
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _apiKeyController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: "Your Google Cloud API Key (Session Only)",
                          hintText: "Paste your API Key here...",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.key),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text("SAVE KEY", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        setGoogleApiKey(_apiKeyController.text.trim());
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("API Key saved for this session!")),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 64, thickness: 2),
            Text(
              "Export Profile - ${currentProfile.name}",
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              "Copy the Profile Code below to send to a parent or teacher. They can paste it into their Typer app to instantly load this student's words, phrases, and progress logs!",
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Center(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.copy, size: 32),
                label: const Text('COPY PROFILE CODE', style: TextStyle(fontSize: 24)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
                ),
                onPressed: () async {
                  final code = exportCurrentProfileJSON();
                  await Clipboard.setData(ClipboardData(text: code));
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile Code copied to clipboard!')),
                  );
                },
              ),
            ),

            if (!kIsWeb) ...[
              const Divider(height: 64, thickness: 2),
              const Text(
                "App Updates",
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                "Check if there is a newer version of Typer available to download and install. Your data will not be lost.",
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.system_update_alt, size: 32),
                  label: const Text('CHECK FOR UPDATES', style: TextStyle(fontSize: 24)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Checking for updates...')),
                    );
                    final downloadUrl = await checkForUpdates();
                    if (!context.mounted) return;
                    
                    if (downloadUrl != null) {
                       final progressNotifier = ValueNotifier<double>(0.0);
                       showDialog(
                         context: context,
                         barrierDismissible: false,
                         builder: (context) {
                           return AlertDialog(
                             title: const Text('Downloading Update...'),
                             content: ValueListenableBuilder<double>(
                               valueListenable: progressNotifier,
                               builder: (context, value, child) {
                                 return Column(
                                   mainAxisSize: MainAxisSize.min,
                                   children: [
                                     LinearProgressIndicator(value: value),
                                     const SizedBox(height: 16),
                                     Text('${(value * 100).toStringAsFixed(1)}%'),
                                   ],
                                 );
                               }
                             ),
                           );
                         }
                       );
                       
                       try {
                         await downloadAndInstallUpdate(downloadUrl, (p) {
                           progressNotifier.value = p;
                         });
                       } catch (e) {
                         if (context.mounted) {
                           Navigator.pop(context); // close dialog
                           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $e')));
                         }
                       }
                    } else {
                       ScaffoldMessenger.of(context).showSnackBar(
                         const SnackBar(content: Text('You are already on the latest version!')),
                       );
                    }
                  },
                ),
              ),
              const SizedBox(height: 32),
            ],
            const SizedBox(height: 16),
            Center(
              child: Text("Typer App Version: v$_appVersion", style: const TextStyle(color: Colors.grey, fontSize: 16)),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
