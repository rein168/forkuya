import 'package:flutter/material.dart';
import 'globals.dart';
import 'main.dart';
import 'dart:convert';
import 'help_screen.dart';
import 'settings_screen.dart';
import 'services/backup_service.dart';
import 'widgets/adult_gate.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'design_tokens.dart';
import 'widgets/save_status.dart';
import 'widgets/teacher_route.dart';

class ProfileSelectionScreen extends StatefulWidget {
  const ProfileSelectionScreen({super.key});

  @override
  State<ProfileSelectionScreen> createState() => _ProfileSelectionScreenState();
}

class _ProfileSelectionScreenState extends State<ProfileSelectionScreen> {
  bool _isLoading = false;

  void _loadProfiles() {
    setState(() {});
  }

  Future<void> _handleProfileTap(String id) async {
    setState(() => _isLoading = true);
    try {
      await loadProfile(id);
    } catch (e) {
      debugPrint("loadProfile($id) failed: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not open this profile. Please try again.")),
        );
      }
      return;
    }
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MainMenuScreen()),
    );
  }

  void _showCreateProfileDialog() {
    final TextEditingController nameCtrl = TextEditingController();
    String selectedAvatar = 'fox';
    bool nameInvalid = false;
    final avatars = ['fox', 'elephant', 'pig', 'octopus'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Create New Profile'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: "Student/Child Name",
                    errorText: nameInvalid ? "Please enter a name to create the profile." : null,
                  ),
                  onChanged: (_) {
                    if (nameInvalid) setDialogState(() => nameInvalid = false);
                  },
                ),
                const SizedBox(height: 20),
                const Text('Select Avatar:', style: TextStyle(fontSize: 16)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: avatars.map((avatar) {
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedAvatar = avatar),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selectedAvatar == avatar ? TyperColors.speakBlue : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 25,
                          backgroundColor: TyperColors.surfaceSunken,
                          backgroundImage: AssetImage('assets/student_$avatar.png'),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty) {
                    setDialogState(() => nameInvalid = true);
                    return;
                  }
                  Navigator.pop(context);
                  setState(() => _isLoading = true);
                  try {
                    await createNewProfile(nameCtrl.text.trim(), selectedAvatar);
                    } catch (e) {
                      debugPrint("createNewProfile failed: $e");
                      if (mounted) {
                        setState(() => _isLoading = false);
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          const SnackBar(content: Text("Could not create the profile. Please try again.")),
                        );
                      }
                      return;
                    }
                  if (mounted) {
                    Navigator.pushReplacement(
                      this.context,
                      MaterialPageRoute(builder: (context) => const MainMenuScreen()),
                    );
                  }
                },
                child: const Text("Create"),
              ),
            ],
          );
        }
      ),
    ).whenComplete(nameCtrl.dispose);
  }

  Future<void> _confirmDeleteProfile(String id) async {
    if (!await requireAdultGate(context, reason: 'Deleting a profile is for teachers and parents.')) return;
    if (!mounted) return;
    final profileName = getProfileInfo(id)?.name ?? 'this student';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $profileName?', style: const TextStyle(color: TyperColors.destructive)),
        content: Text(backupsSupported
            ? "Are you sure you want to delete $profileName's profile? A backup file will be saved to your Documents/Typer folder just in case."
            : "Are you sure you want to completely delete $profileName's profile? This cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: TyperColors.destructive, foregroundColor: TyperColors.surfaceRaised),
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              await autoBackupProfile(id, 'delete');
              await deleteProfile(id);
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
              }
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  Future<void> _importJsonString(String jsonStr) async {
    if (jsonStr.isEmpty) return;
    setState(() => _isLoading = true);

    String importedId = "";
    try {
      importedId = jsonDecode(jsonStr)['id'] ?? "";
    } catch (_) {}

    if (availableProfileIds.contains(importedId)) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMergeChoiceDialog(jsonStr, importedId);
    } else {
      bool success = await importAndMergeProfileJSON(jsonStr);
      if (mounted) {
        setState(() => _isLoading = false);
        if (success) {
          _loadProfiles();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Profile Imported Successfully!")),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("That share code could not be read.")),
          );
        }
      }
    }
  }

  Future<void> _showImportFromFileDialog() async {
    final files = await listProfileBackupFiles();
    if (!mounted) return;
    if (files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No backup files found in your Documents/Typer folder.")),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import from Backup File'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: files.length,
            itemBuilder: (context, index) {
              final file = files[index];
              final fileName = file.path.split(RegExp(r'[/\\]')).last;
              final modified = file.statSync().modified;
              return ListTile(
                leading: const Icon(Icons.insert_drive_file, color: TyperColors.speakBlue),
                title: Text(fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text("${modified.year}-${modified.month.toString().padLeft(2, '0')}-${modified.day.toString().padLeft(2, '0')}"),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    final jsonStr = await readBackupFile(file);
                    await _importJsonString(jsonStr.trim());
                  } catch (e) {
                    debugPrint("readBackupFile failed: $e");
                    if (mounted) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(content: Text("That backup file could not be read. Try saving it again from the other device.")),
                      );
                    }
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
        ],
      ),
    );
  }

  void _showImportDialog() {
    final TextEditingController codeCtrl = TextEditingController();
    bool showPaste = !backupsSupported;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Import Profile'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!showPaste) ...[
                  const Text("Bring this student's profile onto this device using a backup file."),
                  const SizedBox(height: 16),
                  if (backupsSupported)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.folder_open),
                      label: const Text("Choose a backup file..."),
                      onPressed: () {
                        Navigator.pop(context);
                        _showImportFromFileDialog();
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      ),
                    )
                  else
                    const Text("No backup folder is available on this device."),
                ],
                if (showPaste) ...[
                  const Text("Paste the share code that was exported from another device."),
                  const SizedBox(height: 10),
                  TextField(
                    controller: codeCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: "Paste the share code here...",
                    ),
                  ),
                ],
                if (backupsSupported) ...[
                  const SizedBox(height: 12),
                  TextButton.icon(
                    icon: Icon(showPaste ? Icons.folder_open : Icons.paste),
                    label: Text(showPaste
                        ? "Use a backup file instead"
                        : "Advanced: paste a share code instead"),
                    onPressed: () => setDialogState(() => showPaste = !showPaste),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              if (showPaste)
                ElevatedButton(
                  onPressed: () async {
                    final jsonStr = codeCtrl.text.trim();
                    if (jsonStr.isEmpty) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(content: Text('Paste a share code first.')),
                      );
                      return;
                    }
                    Navigator.pop(context);
                    await _importJsonString(jsonStr);
                  },
                  child: const Text("Import"),
                ),
            ],
          );
        },
      ),
    ).whenComplete(codeCtrl.dispose);
  }

  void _showMergeChoiceDialog(String jsonStr, String existingId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Profile Exists!'),
        content: const Text("This profile already exists on your device. Do you want to safely MERGE the incoming updates with your local data, or OVERWRITE your local data completely?"),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              await autoBackupProfile(existingId, 'overwrite');
              bool success = await importAndMergeProfileJSON(jsonStr, overwrite: true);
              if (mounted) {
                setState(() => _isLoading = false);
                if (success) {
                  _loadProfiles();
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(content: Text("Profile Overwritten!")),
                  );
                }
              }
            },
            child: const Text("Overwrite"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              bool success = await importAndMergeProfileJSON(jsonStr, overwrite: false);
              if (mounted) {
                setState(() => _isLoading = false);
                if (success) {
                  _loadProfiles();
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(content: Text("Profile Merged Successfully!")),
                  );
                }
              }
            },
            child: const Text("Safely Merge"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: IconButton(
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
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, size: 32),
            tooltip: 'Settings & Updates',
            onPressed: () async {
              if (!await requireAdultGate(context, reason: 'Settings is for teachers and parents.')) return;
              if (!context.mounted) return;
              Navigator.push(
                context,
                TeacherRoute(builder: (context) => const SettingsScreen(), label: 'Passing to Settings…'),
              ).then((_) {
                // Refresh the profiles list in case they deleted/merged profiles in settings
                _loadProfiles();
              });
            },
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(right: 20.0),
        child: DragTarget<String>(
          onWillAcceptWithDetails: (details) => true,
          onAcceptWithDetails: (details) => _confirmDeleteProfile(details.data),
          builder: (context, candidateData, rejectedData) {
            final isHovered = candidateData.isNotEmpty;
            return FloatingActionButton.large(
              backgroundColor: isHovered ? TyperColors.destructive : TyperColors.hairline,
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Drag a student profile onto this button to delete it — or use the delete icon on the card.')),
                );
              },
              tooltip: 'Drag a student profile here to delete',
              child: Icon(Icons.delete, size: isHovered ? 48 : 36, color: isHovered ? TyperColors.surfaceRaised : TyperColors.inkSecondary),
            );
          },
        ),
      ),      body: Column(
        children: [
          const SaveFailedBanner(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 20,
                    runSpacing: 20,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text("Create Profile"),
                        onPressed: _showCreateProfileDialog,
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15)),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.download),
                        label: const Text("Import Profile"),
                        onPressed: _showImportDialog,
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  Expanded(
                    child: availableProfileIds.isEmpty
                        ? const Center(child: Text("No profiles found. Create one above!"))
                        : Builder(
                            builder: (context) {
                              final screenWidth = MediaQuery.of(context).size.width;
                              int columns = 3;
                              if (screenWidth < 900) {
                                columns = 2;
                              }

                              return GridView.builder(
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  childAspectRatio: 1.5,
                                  crossAxisSpacing: 15,
                                  mainAxisSpacing: 15,
                                ),
                                itemCount: availableProfileIds.length,
                                itemBuilder: (context, index) {
                                  final id = availableProfileIds[index];
                                  final pInfo = getProfileInfo(id);
                                  final name = pInfo?.name ?? "Teacher";
                                  final avatar = pInfo?.avatar ?? "fox";

                                  final isTeacher = pInfo?.isTeacher ?? false;
                                  final cardColor = isTeacher
                                      ? TyperColors.teacherCardBg
                                      : TyperColors.profileCardPalette[id.hashCode.abs() % TyperColors.profileCardPalette.length];
                                  final isSelected = currentProfileId == id;

                                  final card = Card(
                                    color: cardColor,
                                    elevation: isSelected ? 8 : 4,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: isSelected ? const BorderSide(color: TyperColors.speakBlue, width: 3) : BorderSide.none,
                                    ),
                                    child: InkWell(
                                      onTap: () => _handleProfileTap(id),
                                      child: Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            CircleAvatar(
                                              radius: 35,
                                              backgroundColor: isTeacher ? TyperColors.teacherAvatarBg : TyperColors.avatarPlaceholder,
                                              backgroundImage: AssetImage(isTeacher ? 'assets/teacher_avatar.png' : 'assets/student_$avatar.png'),
                                            ),
                                            const SizedBox(height: 10),
                                            Text(
                                              name,
                                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );

                                  if (isTeacher) return card;

                                  return Draggable<String>(
                                    data: id,
                                    feedback: Material(
                                      type: MaterialType.transparency,
                                      child: SizedBox(
                                        width: 250,
                                        height: 150,
                                        child: Opacity(opacity: 0.8, child: card),
                                      ),
                                    ),
                                    childWhenDragging: Opacity(opacity: 0.3, child: card),
                                    child: Stack(
                                      children: [
                                        card,
                                        Positioned(
                                          top: 4,
                                          right: 4,
                                          child: IconButton(
                                            icon: const Icon(Icons.delete_outline, color: TyperColors.destructive),
                                            tooltip: 'Delete this profile',
                                            onPressed: () => _confirmDeleteProfile(id),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                           ),
                                    ),
                  const SizedBox(height: 12),
                  const Text("Tip: Tap the trash icon on a card, or drag it to the bin, to delete.", style: TextStyle(fontSize: 13, color: TyperColors.inkSecondary), textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
  }
}
