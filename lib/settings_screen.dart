import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'help_screen.dart';
import 'updater.dart';
import 'globals.dart';
import 'services/backup_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late String _selectedVoice;
  late bool _ttsEnabled;
  late bool _autoHideKeyboard;
  String _appVersion = "Loading...";
  final TextEditingController _apiKeyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedVoice = getVoicePreference();
    _ttsEnabled = getTtsEnabled();
    _autoHideKeyboard = getAutoHideKeyboard();
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

  Future<void> _checkForUpdatesFlow() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Checking for updates...')),
    );
    final update = await checkForUpdates();
    if (!mounted) return;

    if (update == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You are already on the latest version!')),
      );
      return;
    }

    // Ask before downloading and running an installer.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Available'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('A new version of Typer is available:\n${update.currentVersion}  →  ${update.latestVersion}',
                style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  update.hasChecksum ? Icons.verified_user : Icons.warning_amber,
                  color: update.hasChecksum ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    update.hasChecksum
                        ? 'The download will be verified against the published checksum before installing.'
                        : 'This release does not publish a checksum, so the download cannot be verified. Only continue if you trust the source.',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('The app will close and restart when the installer finishes. Your data will not be lost.',
                style: TextStyle(fontSize: 14, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('NOT NOW')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DOWNLOAD & INSTALL'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

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
            },
          ),
        );
      },
    );

    try {
      await downloadAndInstallUpdate(update, (p) {
        progressNotifier.value = p;
      });
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // close progress dialog
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $e')));
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
                    activeThumbColor: Colors.purple,
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
                      final url = Uri.parse('https://github.com/$githubRepo');
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
                    child: Column(
                      children: [
                        Row(
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
                        const SizedBox(height: 8),
                        const Text(
                          "Safety tip: in the Google Cloud console, restrict this API key so it can only call the Text-to-Speech API. "
                          "The key is kept in memory only and is forgotten when the app closes.",
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          const Divider(height: 64, thickness: 2),
            const Text(
              "On-Screen Keyboard",
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text("Auto-hide when a physical keyboard is used", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              subtitle: const Text(
                "When a USB or Bluetooth keyboard is connected, the on-screen keyboard collapses the first time a key is pressed, giving the letters more room. You can always tap the keyboard button in the top bar to bring it back. Turn this off to always show the on-screen keyboard.",
                style: TextStyle(fontSize: 16),
              ),
              value: _autoHideKeyboard,
              activeThumbColor: Colors.purple,
              onChanged: (bool value) {
                setState(() {
                  _autoHideKeyboard = value;
                  setAutoHideKeyboard(value);
                });
              },
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
              child: Wrap(
                spacing: 24,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.copy, size: 32),
                    label: const Text('COPY PROFILE CODE', style: TextStyle(fontSize: 24)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
                    ),
                    onPressed: () async {
                      final code = exportCurrentProfileJSON();
                      await Clipboard.setData(ClipboardData(text: code));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Profile Code copied to clipboard!')),
                      );
                    },
                  ),
                  if (backupsSupported)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.save_alt, size: 32),
                      label: const Text('SAVE BACKUP FILE', style: TextStyle(fontSize: 24)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
                      ),
                      onPressed: () async {
                        try {
                          final path = await exportCurrentProfileToFile();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Backup saved to:\n$path'), duration: const Duration(seconds: 6)),
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Could not save backup: $e')),
                          );
                        }
                      },
                    ),
                ],
              ),
            ),

            if (updatesSupported) ...[
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
                  onPressed: _checkForUpdatesFlow,
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
