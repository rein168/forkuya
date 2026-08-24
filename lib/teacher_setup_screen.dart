import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'globals.dart';
import 'help_screen.dart';
import 'services/backup_service.dart';
import 'design_tokens.dart';
import 'widgets/save_status.dart';

class TeacherSetupScreen extends StatefulWidget {
  const TeacherSetupScreen({super.key});

  @override
  State<TeacherSetupScreen> createState() => _TeacherSetupScreenState();
}

class _TeacherSetupScreenState extends State<TeacherSetupScreen> {
  // --- Theme Manager Tab State ---
  final TextEditingController _wordController = TextEditingController();
  final TextEditingController _newThemeController = TextEditingController();
  final TextEditingController _customPhraseController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _logScrollController = ScrollController();
  
  final DateTime _selectedDate = DateTime.now();
  String _selectedTheme = "";

  @override
  void initState() {
    super.initState();
    // Pre-select the theme scheduled for today if it exists, otherwise default to the first available or empty
    final activeThemes = getActiveThemesForDate(_selectedDate);
    if (activeThemes.isNotEmpty) {
      _selectedTheme = activeThemes.first;
    } else {
      final allThemes = getAvailableThemes();
      if (allThemes.isNotEmpty) {
        _selectedTheme = allThemes.first;
      }
    }
  }

  @override
  void dispose() {
    _wordController.dispose();
    _newThemeController.dispose();
    _customPhraseController.dispose();
    _focusNode.dispose();
    _logScrollController.dispose();
    super.dispose();
  }

  // --- Theme Manager Logic ---
  void _createNewTheme() {
    final themeName = _newThemeController.text.trim().toUpperCase();
    if (themeName.isEmpty) return;
    if (getAvailableThemes().contains(themeName)) {
      final existing = getWordsForTheme(themeName);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existing.isEmpty
                ? 'A theme named "$themeName" already exists (empty). Select it from the dropdown to add words.'
                : '"$themeName" already exists with ${existing.length} words: ${existing.take(3).join(', ')}${existing.length > 3 ? '…' : ''}',
          ),
          duration: const Duration(seconds: 5),
        ),
      );
      setState(() => _selectedTheme = themeName);
      return;
    }
    setState(() {
      createTheme(themeName);
      _selectedTheme = themeName;
      _newThemeController.clear();
    });
  }

  void _showGlobalThemeImportDialog() {
    // Only offer themes this profile doesn't already have.
    final myThemes = getAvailableThemes();
    final globalBank = getGlobalThemeBank()
        .where((info) => info.profileName != currentProfile.name && !myThemes.contains(info.themeName))
        .toList();
    if (globalBank.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing new to import � this profile already has every shared theme.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Import from Other Profiles'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: globalBank.length,
              itemBuilder: (context, index) {
                final info = globalBank[index];
                String themeName = info.themeName;
                String profileName = info.profileName;
                int wordCount = info.words.length;

                final wordPreview = info.words.take(5).join(', ') + (info.words.length > 5 ? '...' : '');

                return ListTile(
                  title: Text("$themeName ($profileName)", style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('$wordCount words: $wordPreview', maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: const Icon(Icons.download),
                  onTap: () {
                    setState(() {
                      createTheme(themeName);
                      for (String word in info.words) {
                        addWordToTheme(themeName, word);
                      }
                      _selectedTheme = themeName;
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Imported $themeName!')));
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _confirmWipeGlobalBank();
              },
              style: TextButton.styleFrom(foregroundColor: TyperColors.destructive),
              child: const Text('Clear All Profiles'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.download_done),
              label: Text('Import All (${globalBank.length})'),
              onPressed: () {
                setState(() {
                  for (final info in globalBank) {
                    createTheme(info.themeName);
                    for (String word in info.words) {
                      addWordToTheme(info.themeName, word);
                    }
                  }
                  _selectedTheme = globalBank.first.themeName;
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Imported ${globalBank.length} themes!')),
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _addWordToSelectedTheme() {
    final text = _wordController.text.trim().toUpperCase();
    if (text.isNotEmpty && _selectedTheme.isNotEmpty) {
      setState(() {
        addWordToTheme(_selectedTheme, text);
        _wordController.clear();
      });
      _focusNode.requestFocus();
    }
  }

  /// Bulk paste: one word per line (or comma/space separated).
  Future<void> _bulkAddWordsDialog() async {
    final controller = TextEditingController();
    try {
      await showDialog(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Bulk Add Words'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Paste or type words — separate them with new lines, commas, or spaces.'),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  maxLines: 6,
                  autofocus: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'CAT\nDOG\nBIRD',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final raw = controller.text.toUpperCase();
                  final words = raw
                      .split(RegExp(r'[\n,;]+|\s{2,}'))
                      .map((w) => w.trim())
                      .where((w) => w.isNotEmpty)
                      .toSet();
                  if (words.isEmpty) return;
                  setState(() {
                    for (final w in words) {
                      addWordToTheme(_selectedTheme, w);
                    }
                  });
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Added ${words.length} words to "$_selectedTheme".')),
                  );
                },
                child: const Text('Add All'),
              ),
            ],
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _removeWordFromSelectedTheme(String word) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove "$word"?'),
        content: Text('This removes the word from theme "$_selectedTheme". Other themes are not affected.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: TyperColors.destructive, foregroundColor: TyperColors.surfaceRaised),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove Word'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final themeAtDelete = _selectedTheme;
      setState(() {
        removeWordFromTheme(themeAtDelete, word);
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed "$word"'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              setState(() => addWordToTheme(themeAtDelete, word));
            },
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  // --- Phrasebook Logic ---
  /// Characters the student keyboard can produce. Must stay in sync with
  /// CustomKeyboard's two pages.
  static final RegExp _typeableChars = RegExp(r"[A-Za-z0-9 ,.?!':;\-]");

  /// Warns teachers when a saved phrase contains characters the student
  /// cannot type. Returns the set of untypeable characters (empty if all
  /// typeable). Module 2 becomes unwinnable for such phrases.
  Set<String> _untypeableChars(String phrase) {
    return phrase
        .split('')
        .where((c) => c != ' ' && !_typeableChars.hasMatch(c))
        .toSet();
  }

  void _warnUntypeable(String phrase) {
    final bad = _untypeableChars(phrase);
    if (bad.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Heads up: the student keyboard cannot type ${bad.join(' ')}. '
            'The student will not be able to type this phrase in Module 2.',
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  void _saveToPhrasebook(String phrase) {
    final bad = _untypeableChars(phrase);
    setState(() {
      addPhrase(phrase);
      // P1 harden: save but keep INACTIVE so it never appears in Module 2
      // as an unwinnable target. Teacher can edit or activate manually.
      if (bad.isNotEmpty) togglePhraseActive(phrase, false);
      removeTypedSentence(phrase); // Instantly remove from the left column
    });
    if (bad.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Saved, but left INACTIVE: the student keyboard cannot type ${bad.join(' ')}. '
            'Edit the phrase or activate it manually in the list below.',
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved "$phrase" to Phrasebook!'), backgroundColor: TyperColors.correct),
      );
    }
  }

  Future<void> _deleteFromPhrasebook(String phrase) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "$phrase"?'),
        content: const Text('This removes the phrase from the Phrasebook and it will no longer appear in Module 2.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: TyperColors.destructive, foregroundColor: TyperColors.surfaceRaised),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete Phrase'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final wasActive = isPhraseActive(phrase);
      final wasTop = isTopPhrase(phrase);
      setState(() {
        removePhrase(phrase);
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted "$phrase"'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              setState(() {
                addPhrase(phrase);
                if (!wasActive) togglePhraseActive(phrase, false);
                if (wasTop) toggleTopPhrase(phrase, true);
              });
            },
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _editPhraseDialog(String oldPhrase) async {
    final TextEditingController controller = TextEditingController(text: oldPhrase);
    try {
      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Edit Phrase'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              autofocus: true,
              onSubmitted: (_) {
                setState(() {
                  editPhrase(oldPhrase, controller.text);
                });
                _warnUntypeable(controller.text);
                Navigator.pop(context);
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    editPhrase(oldPhrase, controller.text);
                  });
                  _warnUntypeable(controller.text);
                  Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  void _showGlobalPhraseImportDialog() {
    // Only offer phrases this profile doesn't already have.
    final saved = getPhrasebook().toSet();
    final newPhrases = getGlobalPhraseBank().where((p) => !saved.contains(p)).toList();
    if (newPhrases.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing new to import � this profile already has every shared phrase.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Import from Other Profiles'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: newPhrases.length,
                  itemBuilder: (context, index) {
                    String phrase = newPhrases[index];
                    return ListTile(
                      title: Text(phrase, style: const TextStyle(fontWeight: FontWeight.bold)),
                      trailing: const Icon(Icons.add_box, color: TyperColors.speakBlue),
                      onTap: () {
                        setState(() {
                          addPhrase(phrase);
                        });
                        setDialogState(() {
                          newPhrases.remove(phrase);
                        });
                        if (newPhrases.isEmpty && Navigator.canPop(dialogContext)) {
                          Navigator.pop(dialogContext);
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Imported "$phrase"!')),
                        );
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _confirmWipeGlobalBank();
                  },
                  style: TextButton.styleFrom(foregroundColor: TyperColors.destructive),
                  child: const Text('Clear All Profiles'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.playlist_add_check),
                  label: Text('Add All (${newPhrases.length})'),
                  onPressed: () {
                    setState(() {
                      for (final phrase in List<String>.from(newPhrases)) {
                        addPhrase(phrase);
                      }
                      newPhrases.clear();
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(content: Text('Imported all phrases from the other profiles!')),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _clearLog() {
    setState(() {
      clearTypingHistory();
    });
  }

  Future<void> _confirmClearLog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Typing Log?'),
        content: const Text(
          'This removes the list of recently typed sentences shown here. '
          'Phrases already saved to the Phrasebook are not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: TyperColors.destructive, foregroundColor: TyperColors.surfaceRaised),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear Log'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      _clearLog();
    }
  }

  Future<void> _renameThemeDialog() async {
    final TextEditingController controller = TextEditingController(text: _selectedTheme);
    String? errorText;
    try {
      await showDialog(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              void submit() {
                final oldName = _selectedTheme;
                final newName = controller.text.trim().toUpperCase();
                if (newName.isEmpty || newName == oldName) {
                  Navigator.pop(dialogContext);
                  return;
                }
                if (getAvailableThemes().contains(newName)) {
                  setDialogState(() => errorText = 'A theme named "$newName" already exists.');
                  return;
                }
                setState(() {
                  renameTheme(oldName, newName);
                  _selectedTheme = newName;
                });
                Navigator.pop(dialogContext);
              }

              return AlertDialog(
                title: const Text('Rename Theme'),
                content: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: 'New theme name',
                    border: const OutlineInputBorder(),
                    errorText: errorText,
                  ),
                  autofocus: true,
                  onSubmitted: (_) => submit(),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: submit,
                    child: const Text('Rename'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _confirmDeleteTheme() async {
    final theme = _selectedTheme;
    if (theme.isEmpty) return;
    final wordCount = getWordsForTheme(theme).length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "$theme"?', style: const TextStyle(color: TyperColors.destructive)),
        content: Text(
          'This removes the theme, its $wordCount words, and any dates it was scheduled on. '
          'Other profiles are not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: TyperColors.destructive, foregroundColor: TyperColors.surfaceRaised),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete Theme'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final wordsToRestore = getWordsForTheme(theme).toList();
    final datesToRestore = <String>[];
    for (final entry in currentProfile.activeThemesByDate.activeElements) {
      if (entry.split("||").last == theme) datesToRestore.add(entry);
    }
    setState(() {
      deleteTheme(theme);
      _selectedTheme = "";
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted theme "$theme"'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            setState(() {
              createTheme(theme);
              for (final w in wordsToRestore) {
                addWordToTheme(theme, w);
              }
              for (final e in datesToRestore) {
                final parts = e.split("||");
                if (parts.length == 2) addThemeToDate(DateTime.parse(parts[0]), parts[1]);
              }
              _selectedTheme = theme;
            });
          },
        ),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Future<void> _confirmWipeGlobalBank() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear words and phrases on every profile?'),
        content: Text(
          backupsSupported
              ? 'This removes every theme and phrase from ALL profiles on this device. '
                  'A backup of each profile will be saved to your Documents/Typer folder first.'
              : 'This removes every theme and phrase from ALL profiles on this device. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: TyperColors.destructive, foregroundColor: TyperColors.surfaceRaised),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear All Profiles'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    if (backupsSupported) {
      for (final id in List<String>.from(availableProfileIds)) {
        await autoBackupProfile(id, 'wipe');
      }
    }
    await wipeGlobalBank();
    if (!mounted) return;
    setState(() {
      _selectedTheme = "";
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cleared. Every theme and phrase was removed from all profiles.')),
    );
  }

  // --- UI Builders ---
  Widget _buildWordSetupTab() {
    final allThemes = getAvailableThemes();
    final currentWords = _selectedTheme.isNotEmpty ? getWordsForTheme(_selectedTheme) : [];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Row(
            children: [
              Expanded(
                flex: 1,
                child: allThemes.isEmpty 
                  ? const Text("No Themes Created Yet.", style: TextStyle(color: TyperColors.destructive))
                  : DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: "Select Theme to Edit", border: OutlineInputBorder()),
                      initialValue: _selectedTheme.isNotEmpty && allThemes.contains(_selectedTheme) ? _selectedTheme : allThemes.first,
                      items: allThemes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedTheme = val);
                      },
                    ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _newThemeController,
                        decoration: const InputDecoration(
                          labelText: 'Create New Theme (e.g., ANIMALS)',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _createNewTheme(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _createNewTheme,
                      style: ElevatedButton.styleFrom(minimumSize: const Size(80, 55)),
                      child: const Text('Create'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.cloud_download),
                      label: const Text('Other Profiles'),
                      onPressed: _showGlobalThemeImportDialog,
                      style: OutlinedButton.styleFrom(minimumSize: const Size(120, 55)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          const SizedBox(height: 16),
          Divider(thickness: 2, height: 40),

          if (_selectedTheme.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    "Words in Theme: $_selectedTheme",
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                 IconButton(
                   icon: const Icon(Icons.edit, color: TyperColors.speakBlue),
                   tooltip: 'Rename theme',
                   onPressed: _renameThemeDialog,
                 ),
                 IconButton(
                   icon: const Icon(Icons.playlist_add, color: TyperColors.speakBlue),
                   tooltip: 'Bulk add words (paste a list)',
                   onPressed: _bulkAddWordsDialog,
                 ),
                 IconButton(
                  icon: const Icon(Icons.delete_outline, color: TyperColors.destructive),
                  tooltip: 'Delete theme',
                  onPressed: _confirmDeleteTheme,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: TyperColors.phrasesBorder,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    "Played ${getThemeAccessCount(_selectedTheme)} times",
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: TyperColors.phrasesInk),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _wordController,
                    focusNode: _focusNode,
                    decoration: const InputDecoration(
                      labelText: 'Add a new word to this theme',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addWordToSelectedTheme(),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _addWordToSelectedTheme,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(100, 55),
                  ),
                  child: const Text('Add', style: TextStyle(fontSize: 20)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: TyperColors.borderStrong),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: currentWords.isEmpty 
                  ? const Center(child: Text("No words in this theme yet."))
                  : ListView.builder(
                      itemCount: currentWords.length,
                      itemBuilder: (context, index) {
                        final word = currentWords[index];
                        final count = getWordAccessCount(word);
                        return ListTile(
                          title: Row(
                            children: [
                              Text(word, style: const TextStyle(fontSize: 24)),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: TyperColors.phrasesBorder,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  "Speak Pressed: $count",
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: TyperColors.phrasesInk),
                                ),
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: TyperColors.destructive),
                            onPressed: () => _removeWordFromSelectedTheme(word),
                          ),
                        );
                      },
                    ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPhrasebookTab() {
    final history = getTypingHistory().reversed.toList();
    final savedPhrases = getPhrasebook();

    return Row(
      children: [
        // LEFT SIDE: Analytics / Log
        Expanded(
          flex: 1,
          child: Container(
            color: TyperColors.surfaceAlt,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Free Typing Log', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    TextButton.icon(
                       icon: const Icon(Icons.delete_sweep, color: TyperColors.destructive),
                       label: const Text('Clear Log', style: TextStyle(color: TyperColors.destructive)),
                       onPressed: _confirmClearLog,
                     )
                  ],
                ),
                const SizedBox(height: 8),
                const Text('Sentences recently typed by the student.', style: TextStyle(color: TyperColors.inkSecondary)),
                const Divider(),
                Expanded(
                  child: history.isEmpty
                      ? const Center(child: Text("No typing history yet."))
                      : Scrollbar(
                          controller: _logScrollController,
                          child: ListView.builder(
                            padding: const EdgeInsets.only(right: 24.0),
                            controller: _logScrollController,
                            itemCount: history.length,
                            itemBuilder: (context, index) {
                              final text = history[index];
                              final isSaved = savedPhrases.contains(text);
                              return Card(
                                child: ListTile(
                                  title: Text(text, style: const TextStyle(fontSize: 18)),
                                  trailing: isSaved
                                      ? const Icon(Icons.check, color: TyperColors.correct)
                                      : IconButton(
                                          icon: const Icon(Icons.add_box, color: TyperColors.speakBlue),
                                          tooltip: "Add to Phrasebook",
                                          onPressed: () => _saveToPhrasebook(text),
                                        ),
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
        const VerticalDivider(width: 1, thickness: 1),
        // RIGHT SIDE: Saved Phrasebook
        Expanded(
          flex: 1,
          child: Container(
            color: TyperColors.surfaceRaised,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Saved Phrasebook', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.cloud_download),
                      label: const Text('Other Profiles'),
                      onPressed: _showGlobalPhraseImportDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _customPhraseController,
                        decoration: const InputDecoration(
                          labelText: 'Type a custom phrase directly...',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) {
                          if (_customPhraseController.text.trim().isNotEmpty) {
                            _saveToPhrasebook(_customPhraseController.text.trim());
                            _customPhraseController.clear();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.add_box, color: TyperColors.speakBlue, size: 40),
                      tooltip: 'Add phrase',
                      onPressed: () {
                        if (_customPhraseController.text.trim().isNotEmpty) {
                          _saveToPhrasebook(_customPhraseController.text.trim());
                          _customPhraseController.clear();
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('These phrases will appear in Module 2.', style: TextStyle(color: TyperColors.inkSecondary)),
                const Divider(),
                Expanded(
                  child: savedPhrases.isEmpty
                      ? const Center(child: Text("No phrases saved."))
                      : ListView.builder(
                          padding: const EdgeInsets.only(right: 24.0),
                          itemCount: savedPhrases.length,
                          itemBuilder: (context, index) {
                            final phrase = savedPhrases[index];
                            final isActive = isPhraseActive(phrase);
                            final playCount = getPhraseAccessCount(phrase);
                            return Card(
                              color: isActive ? TyperColors.selectionWash : TyperColors.surfaceSunken,
                              child: InkWell(
                                onDoubleTap: () => _editPhraseDialog(phrase),
                                child: ListTile(
                                  leading: Checkbox(
                                    value: isActive,
                                    onChanged: (bool? val) {
                                      if (val != null) {
                                        setState(() {
                                          togglePhraseActive(phrase, val);
                                        });
                                      }
                                    },
                                  ),
                                  title: Text(
                                    phrase, 
                                    style: TextStyle(
                                      fontSize: 20, 
                                      fontWeight: FontWeight.w500,
                                      decoration: isActive ? TextDecoration.none : TextDecoration.lineThrough,
                                      color: isActive ? TyperColors.ink : TyperColors.inkSecondary,
                                    ),
                                  ),
                                  subtitle: Text("Played $playCount times", style: const TextStyle(color: TyperColors.phrasesInk, fontSize: 12)),
                                  isThreeLine: false,
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, color: TyperColors.speakBlue),
                                        tooltip: 'Edit phrase',
                                        onPressed: () => _editPhraseDialog(phrase),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          isTopPhrase(phrase) ? Icons.star : Icons.star_border,
                                          color: isTopPhrase(phrase) ? TyperColors.warningInk : TyperColors.inkSecondary,
                                        ),
                                        tooltip: "Pin to Top (Max 10)",
                                        onPressed: () {
                                          final success = toggleTopPhrase(phrase, !isTopPhrase(phrase));
                                          if (!success) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text("You can only pin up to 10 top phrases."), backgroundColor: TyperColors.warningInk),
                                            );
                                          } else {
                                            setState(() {});
                                          }
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: TyperColors.destructive),
                                        onPressed: () => _deleteFromPhrasebook(phrase),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildThemeSchedulerTab() {
    final allThemes = getAvailableThemes();
    final today = DateTime.now();

    return Row(
      children: [
        // Left Column: Available Themes (Draggables)
        Expanded(
          flex: 1,
          child: Container(
            color: TyperColors.phrasesWash,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    const Text('Available Themes', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.cloud_download),
                      label: const Text('Other Profiles'),
                      onPressed: _showGlobalThemeImportDialog,
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Drag a theme to the calendar to schedule it.', style: TextStyle(color: TyperColors.inkSecondary)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.lightbulb_outline, size: 14, color: TyperColors.inkSecondary),
                        SizedBox(width: 4),
                        Expanded(child: Text('Tap ✎ to edit words • Drag to schedule for a day', style: TextStyle(fontSize: 12, color: TyperColors.inkSecondary))),
                      ],
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: allThemes.isEmpty 
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text("No themes yet — let's make one!", style: TextStyle(color: TyperColors.inkSecondary)),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: () => DefaultTabController.of(context).animateTo(1),
                              icon: const Icon(Icons.edit),
                              label: const Text("Create your first theme"),
                              style: ElevatedButton.styleFrom(backgroundColor: TyperColors.speakBlue, foregroundColor: TyperColors.surfaceRaised),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: allThemes.length,
                        itemBuilder: (context, index) {
                          final theme = allThemes[index];
                          final words = getWordsForTheme(theme);
                          final wordCount = words.length;
                          final wordPreview = words.take(5).join(', ') + (words.length > 5 ? '...' : '');
                          return Draggable<String>(
                            data: theme,
                            feedback: Material(
                              elevation: 8,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(color: TyperColors.phrasesInk, borderRadius: BorderRadius.circular(8)),
                                child: Text(theme, style: const TextStyle(color: TyperColors.surfaceRaised, fontSize: 20, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            childWhenDragging: Card(
                              color: TyperColors.hairline,
                              child: ListTile(title: Text(theme, style: const TextStyle(color: TyperColors.inkSecondary))),
                            ),
                            child: GestureDetector(
                              onDoubleTap: () {
                                setState(() {
                                  _selectedTheme = theme;
                                });
                                DefaultTabController.of(context).animateTo(1);
                              },
                              child: Card(
                                elevation: 2,
                                child: ListTile(
                                  leading: const Icon(Icons.drag_indicator, color: TyperColors.phrasesInk),
                                  title: Text(theme, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('$wordCount words: $wordPreview', maxLines: 2, overflow: TextOverflow.ellipsis),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // P2 adapt: tap-to-schedule for teachers who
                                      // can't or prefer not to drag.
                                      IconButton(
                                        icon: const Icon(Icons.calendar_today, color: TyperColors.correct, size: 22),
                                        tooltip: 'Schedule for tomorrow',
                                        onPressed: () {
                                          final tomorrow = today.add(const Duration(days: 1));
                                          setState(() => addThemeToDate(tomorrow, theme));
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Scheduled "$theme" for Tomorrow ✓'), backgroundColor: TyperColors.correct),
                                          );
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, color: TyperColors.speakBlue),
                                        tooltip: 'Edit words in this theme',
                                        onPressed: () {
                                          setState(() {
                                            _selectedTheme = theme;
                                          });
                                          DefaultTabController.of(context).animateTo(1);
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                ),
              ],
            ),
          ),
        ),
        const VerticalDivider(width: 1, thickness: 1),
        // Right Column: Calendar (Drag Targets)
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Schedule (Next 7 Days)', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    itemCount: 7,
                    itemBuilder: (context, index) {
                      final targetDate = today.add(Duration(days: index));
                      final dateLabel = index == 0 ? "Today" : index == 1 ? "Tomorrow" : "${targetDate.month}/${targetDate.day}";
                      final activeThemes = getActiveThemesForDate(targetDate);
                      
                      return DragTarget<String>(
                        onAcceptWithDetails: (details) {
                          HapticFeedback.lightImpact();
                          setState(() {
                            addThemeToDate(targetDate, details.data);
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.check_circle, color: TyperColors.surfaceRaised, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text('Scheduled "${details.data}" for $dateLabel ✓', style: const TextStyle(fontWeight: FontWeight.bold))),
                                ],
                              ),
                              backgroundColor: TyperColors.correct,
                              duration: const Duration(milliseconds: 1400),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        builder: (context, candidateData, rejectedData) {
                          final isHovering = candidateData.isNotEmpty;
                          return Card(
                            color: isHovering ? TyperColors.selectionHover : TyperColors.surfaceRaised,
                            elevation: isHovering ? 6 : 1,
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "$dateLabel - ${formatDate(targetDate)}",
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  if (activeThemes.isEmpty)
                                    const Text("No themes scheduled.", style: TextStyle(color: TyperColors.inkSecondary, fontStyle: FontStyle.italic))
                                  else
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: activeThemes.map((theme) {
                                        return Chip(
                                          label: Text(theme, style: const TextStyle(fontWeight: FontWeight.bold, color: TyperColors.surfaceRaised)),
                                          backgroundColor: TyperColors.speakBlue,
                                          deleteIcon: const Icon(Icons.close, color: TyperColors.surfaceRaised, size: 18),
                                          onDeleted: () => _confirmUnscheduleTheme(targetDate, theme),
                                        );
                                      }).toList(),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmUnscheduleTheme(DateTime date, String theme) async {
    final dateLabel = formatDate(date);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Unschedule "$theme"?'),
        content: Text('This removes the theme from $dateLabel. The theme and its words are not deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Unschedule'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() {
        removeThemeFromDate(date, theme);
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed "$theme" from $dateLabel'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              setState(() => addThemeToDate(date, theme));
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
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
          title: Text('Word & Phrase Setup - ${currentProfile.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Builder(
              builder: (context) {
                final TabController tabController = DefaultTabController.of(context);

                return AnimatedBuilder(
                  animation: tabController,
                  builder: (context, _) {
                    Widget buildCardTab(int index, IconData icon, String text) {
                      final isSelected = tabController.index == index;
                      return Tab(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          decoration: BoxDecoration(
                            color: isSelected ? TyperColors.selectionWash : TyperColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? TyperColors.speakBlue : TyperColors.hairline, 
                              width: isSelected ? 2 : 1
                            ),
                            boxShadow: [
                              if (!isSelected) const BoxShadow(color: TyperColors.shadowSoft, blurRadius: 2, offset: Offset(0, 1))
                            ],
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center, 
                              children: [
                                Icon(icon, color: isSelected ? TyperColors.selectionDeep : TyperColors.inkSecondary), 
                                const SizedBox(width: 8), 
                                Text(
                                  text, 
                                  style: TextStyle(
                                    fontSize: 16, 
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? TyperColors.selectionDeep : TyperColors.inkSecondary,
                                  ),
                                ),
                              ]
                            )
                          )
                        ),
                      );
                    }

                    return TabBar(
                      indicator: const BoxDecoration(), // Hide default indicator
                      labelPadding: EdgeInsets.zero,
                      tabs: [
                        buildCardTab(0, Icons.calendar_month, "Word Theme Scheduler"),
                        buildCardTab(1, Icons.edit, "Word Setup"),
                        buildCardTab(2, Icons.forum, "Phrasebook"),
                      ],
                    );
                  }
                );
              }
            ),
          ),
        ),
        body: Column(
          children: [
            const SaveFailedBanner(),
            Expanded(
              child: TabBarView(
                children: [
                  _buildThemeSchedulerTab(),
                  _buildWordSetupTab(),
                  _buildPhrasebookTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
