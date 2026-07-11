import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'globals.dart';
import 'main.dart';
import 'dart:convert';
import 'help_screen.dart';
import 'settings_screen.dart';
import 'services/backup_service.dart';
import 'widgets/adult_gate.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

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
    await loadProfile(id);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MainMenuScreen()),
    );
  }

  void _showCreateProfileDialog() {
    final TextEditingController nameCtrl = TextEditingController();
    String selectedAvatar = 'fox';
    final avatars = ['fox', 'elephant', 'pig', 'octopus'];
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text("Create New Profile", style: GoogleFonts.fredoka()),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: "Student/Child Name"),
                ),
                const SizedBox(height: 20),
                Text("Select Avatar:", style: GoogleFonts.fredoka(fontSize: 16)),
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
                            color: selectedAvatar == avatar ? Colors.blue : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 25,
                          backgroundColor: Colors.grey.shade200,
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
                  if (nameCtrl.text.trim().isNotEmpty) {
                    Navigator.pop(context);
                    setState(() => _isLoading = true);
                    await createNewProfile(nameCtrl.text.trim(), selectedAvatar);
                    if (mounted) {
                      Navigator.pushReplacement(
                        this.context,
                        MaterialPageRoute(builder: (context) => const MainMenuScreen()),
                      );
                    }
                  }
                },
                child: const Text("Create"),
              ),
            ],
          );
        }
      ),
    );
  }

  Future<void> _confirmDeleteProfile(String id) async {
    if (!await requireAdultGate(context, reason: 'Deleting a profile is for teachers and parents.')) return;
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Delete Profile?", style: GoogleFonts.fredoka(color: Colors.red)),
        content: Text(backupsSupported
            ? "Are you sure you want to delete this student's profile? A backup file will be saved to your Documents/Typer folder just in case."
            : "Are you sure you want to completely delete this student's profile? This cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
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

    // Determine if it already exists to show Overwrite vs Merge
    String importedId = "";
    try {
      importedId = jsonDecode(jsonStr)['id'] ?? "";
    } catch (_) {}

    if (availableProfileIds.contains(importedId)) {
      // Exists locally! Ask to Merge or Overwrite
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMergeChoiceDialog(jsonStr, importedId);
    } else {
      // New profile, just import
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
            const SnackBar(content: Text("Invalid Profile Code.")),
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
        title: Text("Import from Backup File", style: GoogleFonts.fredoka()),
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
                leading: const Icon(Icons.insert_drive_file, color: Colors.blue),
                title: Text(fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text("${modified.year}-${modified.month.toString().padLeft(2, '0')}-${modified.day.toString().padLeft(2, '0')}"),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    final jsonStr = await readBackupFile(file);
                    await _importJsonString(jsonStr.trim());
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(content: Text("Could not read backup file: $e")),
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Import/Update Profile", style: GoogleFonts.fredoka()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Paste the Profile Code below to import a new student or update an existing one."),
            const SizedBox(height: 10),
            TextField(
              controller: codeCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "Paste JSON code here...",
              ),
            ),
            if (backupsSupported) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                icon: const Icon(Icons.folder_open),
                label: const Text("Or import from a backup file..."),
                onPressed: () {
                  Navigator.pop(context);
                  _showImportFromFileDialog();
                },
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final jsonStr = codeCtrl.text.trim();
              if (jsonStr.isEmpty) return;
              Navigator.pop(context);
              await _importJsonString(jsonStr);
            },
            child: const Text("Import"),
          ),
        ],
      ),
    );
  }

  void _showMergeChoiceDialog(String jsonStr, String existingId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Profile Exists!", style: GoogleFonts.fredoka()),
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
        title: Text('Select Profile', style: GoogleFonts.fredoka(fontWeight: FontWeight.bold)),
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
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
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
              backgroundColor: isHovered ? Colors.red : Colors.grey.shade300,
              onPressed: () {},
              tooltip: 'Drag a student profile here to delete',
              child: Icon(Icons.delete, size: isHovered ? 48 : 36, color: isHovered ? Colors.white : Colors.grey.shade600),
            );
          },
        ),
      ),
      body: _isLoading
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
                        label: const Text("Import Profile Code"),
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

                                  final cardColors = [
                                    Colors.pink.shade50,
                                    Colors.orange.shade50,
                                    Colors.yellow.shade50,
                                    Colors.purple.shade50,
                                    Colors.cyan.shade50,
                                  ];
                                  final isTeacher = name == 'Teacher';
                                  final cardColor = isTeacher ? Colors.lightGreen.shade100 : cardColors[id.hashCode.abs() % cardColors.length];
                                  final isSelected = currentProfileId == id;

                                  final card = Card(
                                    color: cardColor,
                                    elevation: isSelected ? 8 : 4,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: isSelected ? const BorderSide(color: Colors.blue, width: 3) : BorderSide.none,
                                    ),
                                    child: InkWell(
                                      onTap: () => _handleProfileTap(id),
                                      child: Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            CircleAvatar(
                                              radius: 35,
                                              backgroundColor: isTeacher ? Colors.lightGreen.shade300 : Colors.white70,
                                              backgroundImage: AssetImage(isTeacher ? 'assets/teacher_avatar.png' : 'assets/student_$avatar.png'),
                                            ),
                                            const SizedBox(height: 10),
                                            Text(
                                              name,
                                              style: GoogleFonts.fredoka(fontSize: 24, fontWeight: FontWeight.bold),
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
                                    child: card,
                                  );
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
