import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'help_screen.dart';
import 'updater.dart';
import 'globals.dart';
import 'services/backup_service.dart';
import 'widgets/save_status.dart';
import 'widgets/tts_status.dart';
import 'web_install.dart';
import 'design_tokens.dart';
import 'piper.dart';
import 'kokoro.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late String _selectedVoice;
  late bool _ttsEnabled;
  late bool _autoHideKeyboard;
  late bool _offlineVoice;
  String _appVersion = "Loading...";
  late TextEditingController _teacherNameController;
  Timer? _piperPollTimer;
  double _piperProgressValue = 0;
  String _piperStateStr = 'idle';

  @override
  void initState() {
    super.initState();
    _selectedVoice = getVoicePreference();
    if (_selectedVoice == 'MAN') {
      _selectedVoice = 'BOY';
      setVoicePreference('BOY');
    } else if (_selectedVoice == 'WOMAN') {
      _selectedVoice = 'GIRL';
      setVoicePreference('GIRL');
    }
    _ttsEnabled = getTtsEnabled();
    _autoHideKeyboard = getAutoHideKeyboard();
    _offlineVoice = getOfflineVoiceEnabled();
    _teacherNameController = TextEditingController(text: currentProfile.name);
    _loadVersion();
    // Warm Piper if already enabled (now ON by default)
    if (_offlineVoice && kIsWeb && piperSupported()) warmOfflineVoice();
    // Poll Piper progress/state for the tiny download bar (web only)
    if (kIsWeb) {
      _piperPollTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
        if (!mounted) return;
        final isKokoro = getOfflineEngine() == 'kokoro';
        final p = isKokoro ? kokoroProgress() : piperProgress();
        final s = isKokoro ? kokoroState() : piperState();
        if (p != _piperProgressValue || s != _piperStateStr) {
          setState(() {
            _piperProgressValue = p;
            _piperStateStr = s;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    // TEST VOICE speaks here; audio must not outlive the surface.
    stopAllSpeech();
    _piperPollTimer?.cancel();
    _teacherNameController.dispose();
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
                  color: update.hasChecksum ? TyperColors.correct : TyperColors.warningInk,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    update.hasChecksum
                        ? 'The download will be verified against the published checksum before installing.'
                        : 'This release does not publish a checksum, so the download cannot be verified. Only continue if you trust the source.',
                    style: const TextStyle(fontSize: 14, color: TyperColors.inkSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('The app will close and restart when the installer finishes. Your data will not be lost.',
                style: TextStyle(fontSize: 14, color: TyperColors.inkSecondary)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not Now')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: TyperColors.speakBlue, foregroundColor: TyperColors.surfaceRaised),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Download & Install'),
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
      debugPrint("Update failed: $e");
      if (mounted) {
        Navigator.pop(context); // close progress dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('The update could not be downloaded. Check your internet connection and try again.')),
        );
      }
    }
  }

  void _saveTeacherName() {
    final name = _teacherNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name.')),
      );
      return;
    }
    setState(() {
      currentProfile.name = name;
    });
    // Persist immediately; saveCurrentProfile is chained so fire-and-forget is safe
    saveCurrentProfile().then((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Teacher name saved as "$name".')),
      );
    });
  }

  void _testVoice() {
    String intro = "Hello! This is how I sound.";
    if (_selectedVoice == "BOY") intro = "Hello! I am a male, this is how I sound.";
    if (_selectedVoice == "GIRL") intro = "Hello! I am Piper, a female. This is how I sound.";
    speakWithCloud(intro);
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
        actions: [
          // TEST VOICE triggers Cloud speech, so this surface carries the
          // same voice-status contract as the typing screens.
          const VoiceStatusChip(),
          const SizedBox(width: 12),
        ],
      ),
      body: BannerOverlay(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SaveFailedBanner(),
            if (currentProfile.isTeacher) ...[
              const Text(
                "Teacher Profile",
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                "This name appears on the profile card. Change it to your own name so students know who their teacher is.",
                style: TextStyle(fontSize: 16, color: TyperColors.inkSecondary),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _teacherNameController,
                      decoration: const InputDecoration(
                        labelText: "Teacher name",
                        hintText: "e.g. Ms. Santos",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.badge),
                      ),
                      textCapitalization: TextCapitalization.words,
                      onSubmitted: (_) => _saveTeacherName(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text("Save"),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      backgroundColor: TyperColors.speakBlue,
                      foregroundColor: TyperColors.surfaceRaised,
                    ),
                    onPressed: _saveTeacherName,
                  ),
                ],
              ),
              const Divider(height: 64, thickness: 2),
            ],
            const Text(
              "Reading Font",
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              "Choose the typeface used across the whole app. All three are designed to be easy for young readers.",
              style: TextStyle(fontSize: 18, color: TyperColors.inkSecondary),
            ),
            const SizedBox(height: 32),
            Center(
              child: SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: 'Fredoka',
                    label: Padding(
                      padding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
                      child: Column(
                        children: [
                          Text('Fredoka', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                          Text('rounded and friendly', style: TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                  ButtonSegment(
                    value: 'Lexend',
                    label: Padding(
                      padding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
                      child: Column(
                        children: [
                          Text('Lexend', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                          Text('easy to read', style: TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                  ButtonSegment(
                    value: 'Andika',
                    label: Padding(
                      padding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
                      child: Column(
                        children: [
                          Text('Andika', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                          Text('for new readers', style: TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                ],
                selected: {getFontPreference()},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() {});
                  setFontPreference(newSelection.first);
                },
              ),
            ),
            const SizedBox(height: 48),
            const Text(
              "Voice Profile",
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              "Select a Voice Profile. This determines the gender of the speaker for both the online Cloud Voices and the offline Natural Voices.",
              style: TextStyle(fontSize: 18, color: TyperColors.inkSecondary),
            ),
            const SizedBox(height: 32),
            Center(
              child: SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: 'GIRL',
                    label: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text('Piper (Female)', style: TextStyle(fontSize: 24)),
                    ),
                  ),
                  ButtonSegment(
                    value: 'BOY',
                    label: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text('Joe (Male)', style: TextStyle(fontSize: 24)),
                    ),
                  ),
                ],
                selected: {_selectedVoice},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() {
                    _selectedVoice = newSelection.first;
                    setVoicePreference(_selectedVoice);
                    if (_offlineVoice) warmOfflineVoice();
                  });
                  _testVoice();
                },
              ),
            ),
            const SizedBox(height: 48),
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.record_voice_over, size: 32),
                label: const Text('Test Voice', style: TextStyle(fontSize: 24)),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 48, vertical: 24),
                  backgroundColor: TyperColors.speakBlue,
                  foregroundColor: TyperColors.surfaceRaised,
                ),
                onPressed: _testVoice,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: SwitchListTile(
                    title: const Text("Use Cloud Voices", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    subtitle: const Text(
                      "Cloud voices are powered by Puter.js, providing premium high-quality voices entirely for free. An internet connection is required.",
                      style: TextStyle(fontSize: 16)
                    ),
                    value: _ttsEnabled,
                    activeThumbColor: TyperColors.phrasesInk,
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
                    icon: const Icon(Icons.star, color: TyperColors.warningInk, size: 32),
                    label: const Text('Star us on GitHub!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                      backgroundColor: TyperColors.warningSurface,
                      foregroundColor: TyperColors.warningInk,
                      elevation: 4,
                      side: BorderSide(color: TyperColors.warningBorder, width: 2),
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
            if (kIsWeb) ...[
            const Divider(height: 64, thickness: 2),
            const Text(
              "Offline Voice",
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),            SwitchListTile(
              title: const Text("Use an offline natural voice", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              subtitle: const Text(
                "Runs a natural voice fully on this device — works with no internet and never depends on an outside service. "
                "It downloads a one-time voice pack the first time it loads, then always works offline.",
                style: TextStyle(fontSize: 16),
              ),
              value: _offlineVoice,
              activeThumbColor: TyperColors.phrasesInk,
              onChanged: (bool value) {
                setState(() {
                  _offlineVoice = value;
                  setOfflineVoiceEnabled(value);
                });
                if (value && kIsWeb) warmOfflineVoice();
              },
            ),
            if (_offlineVoice && kIsWeb) ...[
              const SizedBox(height: 16),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    const Text(
                      "Engine:",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 16),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment<String>(
                          value: 'piper',
                          label: Padding(padding: EdgeInsets.all(8.0), child: Text('Piper (Fast, 60MB)')),
                        ),
                        ButtonSegment<String>(
                          value: 'kokoro',
                          label: Padding(padding: EdgeInsets.all(8.0), child: Text('Kokoro (HQ, 300MB)')),
                        ),
                      ],
                      selected: {getOfflineEngine()},
                      onSelectionChanged: (Set<String> newSelection) {
                        setState(() {
                          setOfflineEngine(newSelection.first);
                          warmOfflineVoice();
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (_piperStateStr == 'loading')
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(
                      value: _piperProgressValue > 0.02 ? _piperProgressValue : null,
                      minHeight: 6,
                      backgroundColor: TyperColors.hairline,
                      valueColor: const AlwaysStoppedAnimation<Color>(TyperColors.speakBlue),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _piperProgressValue > 0
                          ? 'Downloading ${getOfflineEngine() == "kokoro" ? "Kokoro" : "Piper"}... ${(_piperProgressValue * 100).toStringAsFixed(0)}%'
                          : 'Preparing offline voice...',
                      style: const TextStyle(fontSize: 14, color: TyperColors.inkSecondary),
                    ),
                  ],
                )
              else if (_piperStateStr == 'ready')
                const Padding(
                  padding: EdgeInsets.only(top: 8.0, left: 16.0),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, size: 18, color: TyperColors.correct),
                      SizedBox(width: 6),
                      Text('Offline voice ready — works with no internet',
                          style: TextStyle(fontSize: 14, color: TyperColors.inkSecondary)),
                    ],
                  ),
                )
              else if (_piperStateStr == 'error')
                const Padding(
                  padding: EdgeInsets.only(top: 8.0, left: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Offline voice failed to load.',
                          style: TextStyle(fontSize: 14, color: TyperColors.destructive)),
                    ],
                  ),
                ),
              const SizedBox(height: 6),
              TextButton.icon(
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry download'),
                onPressed: () {
                  warmOfflineVoice();
                  setState(() => _piperStateStr = 'loading');
                },
              ),
            ],
            ],
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
              activeThumbColor: TyperColors.phrasesInk,
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
              "Share this student's profile with a parent or teacher. Copy the share code to the clipboard, or save a backup file they can open in their Typer app to instantly load this student's words, phrases, and progress logs!",
              style: TextStyle(fontSize: 18, color: TyperColors.inkSecondary),
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
                    label: const Text('Copy Share Code', style: TextStyle(fontSize: 24)),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 48, vertical: 24),
                    ),
                    onPressed: () async {
                      final code = exportCurrentProfileJSON();
                      await Clipboard.setData(ClipboardData(text: code));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Share code copied!')),
                      );
                    },
                  ),
                  if (backupsSupported)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.save_alt, size: 32),
                      label: const Text('Save Backup File', style: TextStyle(fontSize: 24)),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 48, vertical: 24),
                      ),
                      onPressed: () async {
                        try {
                          final path = await exportCurrentProfileToFile();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Backup saved to:\n$path'), duration: const Duration(seconds: 6)),
                          );
                        } catch (e) {
                          debugPrint("Backup save failed: $e");
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('The backup could not be saved. Check your storage and try again.')),
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
                style: TextStyle(fontSize: 18, color: TyperColors.inkSecondary),
              ),
              const SizedBox(height: 24),
              Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.system_update_alt, size: 32),
                  label: const Text('Check for Updates', style: TextStyle(fontSize: 24)),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 48, vertical: 24),
                    backgroundColor: TyperColors.speakBlue,
                    foregroundColor: TyperColors.surfaceRaised,
                  ),
                  onPressed: _checkForUpdatesFlow,
                ),
              ),
              const SizedBox(height: 32),
            ],
            const SizedBox(height: 32),
            const Text(
              'Install as an App',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Put Typer on the home screen for a fullscreen, offline-capable experience.',
              style: TextStyle(fontSize: 18, color: TyperColors.inkSecondary),
            ),
            const SizedBox(height: 16),
            if (kIsWeb && canShowInstallPrompt())
              Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.install_mobile, size: 28),
                  label: const Text('Install Now', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                    backgroundColor: TyperColors.speakBlue,
                    foregroundColor: TyperColors.surfaceRaised,
                  ),
                  onPressed: () => showInstallPrompt(),
                ),
              )
            else if (kIsWeb)
              const Padding(
                padding: EdgeInsets.only(bottom: 8.0),
                child: Text(
                  'To install: in Chrome, open the browser menu (⋮) and choose "Add to Home screen". '
                  'On iPhone/iPad, tap the Share button and choose "Add to Home Screen".',
                  style: TextStyle(fontSize: 16, color: TyperColors.inkSecondary),
                ),
              ),
            const SizedBox(height: 16),
            Center(
              child: Text("Typer App Version: v$_appVersion", style: const TextStyle(color: TyperColors.inkSecondary, fontSize: 16)),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
