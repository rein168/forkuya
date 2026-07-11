import 'package:flutter/material.dart';
import 'globals.dart';
import 'help_screen.dart';

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
    if (themeName.isNotEmpty) {
      setState(() {
        createTheme(themeName);
        _selectedTheme = themeName;
        _newThemeController.clear();
      });
    }
  }

  void _showGlobalThemeImportDialog() {
    final globalBank = getGlobalThemeBank();
    if (globalBank.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Global Bank is empty!')));
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Import from Global Bank'),
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
                
                Color titleColor;
                if (profileName == currentProfile.name) {
                  titleColor = Colors.black;
                } else if (getAvailableThemes().contains(themeName)) {
                  titleColor = Colors.green;
                } else {
                  titleColor = Colors.red;
                }
                
                final wordPreview = info.words.take(5).join(', ') + (info.words.length > 5 ? '...' : '');
                
                return ListTile(
                  title: Text("$themeName ($profileName)", style: TextStyle(fontWeight: FontWeight.bold, color: titleColor)),
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
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
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

  void _removeWordFromSelectedTheme(String word) {
    setState(() {
      removeWordFromTheme(_selectedTheme, word);
    });
  }

  // Removed _scheduleThemeForDate as scheduling is now drag-and-drop

  // --- Phrasebook Logic ---
  void _saveToPhrasebook(String phrase) {
    setState(() {
      addPhrase(phrase);
      removeTypedSentence(phrase); // Instantly remove from the left column
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved "$phrase" to Phrasebook!'), backgroundColor: Colors.green),
    );
  }

  void _deleteFromPhrasebook(String phrase) {
    setState(() {
      removePhrase(phrase);
    });
  }

  void _editPhraseDialog(String oldPhrase) {
    final TextEditingController controller = TextEditingController(text: oldPhrase);
    showDialog(
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
              Navigator.pop(context);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  editPhrase(oldPhrase, controller.text);
                });
                Navigator.pop(context);
              },
              child: const Text('SAVE'),
            ),
          ],
        );
      },
    );
  }

  void _showGlobalPhraseImportDialog() {
    final globalPhrases = getGlobalPhraseBank();
    if (globalPhrases.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Global Phrase Bank is empty!')));
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Import Phrases from Global Bank'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: globalPhrases.length,
              itemBuilder: (context, index) {
                String phrase = globalPhrases.elementAt(index);
                bool alreadySaved = getPhrasebook().contains(phrase);
                return ListTile(
                  title: Text(phrase, style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: alreadySaved 
                      ? const Icon(Icons.check, color: Colors.green)
                      : const Icon(Icons.add_box, color: Colors.blue),
                  onTap: () {
                    if (!alreadySaved) {
                      setState(() {
                        addPhrase(phrase);
                      });
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Imported "$phrase"!')));
                    }
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('DONE'),
            ),
          ],
        );
      },
    );
  }

  void _clearLog() {
    setState(() {
      clearTypingHistory();
    });
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

          // 2. THEME SELECTOR / CREATOR
          Row(
            children: [
              Expanded(
                flex: 1,
                child: allThemes.isEmpty 
                  ? const Text("No Themes Created Yet.", style: TextStyle(color: Colors.red))
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
                      label: const Text('Global Bank'),
                      onPressed: _showGlobalThemeImportDialog,
                      style: OutlinedButton.styleFrom(minimumSize: const Size(120, 55)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          const SizedBox(height: 16),Divider(thickness: 2, height: 40),

          // 4. WORD MANAGER FOR SELECTED THEME
          if (_selectedTheme.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Words in Theme: $_selectedTheme", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    "Played ${getThemeAccessCount(_selectedTheme)} times", 
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.purple),
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
                  border: Border.all(color: Colors.grey.shade400),
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
                                  color: Colors.purple.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  "Speak Pressed: $count",
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purple),
                                ),
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
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
            color: Colors.grey.shade100,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Free Typing Log', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    TextButton.icon(
                      icon: const Icon(Icons.delete_sweep, color: Colors.red),
                      label: const Text('Clear Log', style: TextStyle(color: Colors.red)),
                      onPressed: _clearLog,
                    )
                  ],
                ),
                const SizedBox(height: 8),
                const Text('Sentences recently typed by the student.', style: TextStyle(color: Colors.grey)),
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
                                      ? const Icon(Icons.check, color: Colors.green)
                                      : IconButton(
                                          icon: const Icon(Icons.add_box, color: Colors.blue),
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
            color: Colors.white,
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
                      label: const Text('Global Bank'),
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
                      icon: const Icon(Icons.add_box, color: Colors.blue, size: 40),
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
                const Text('These phrases will appear in Module 2.', style: TextStyle(color: Colors.grey)),
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
                              color: isActive ? Colors.blue.shade50 : Colors.grey.shade200,
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
                                      color: isActive ? Colors.black : Colors.grey,
                                    ),
                                  ),
                                  subtitle: Text("Played $playCount times\n(Double-click to edit)", style: const TextStyle(color: Colors.purple, fontSize: 12)),
                                  isThreeLine: true,
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          isTopPhrase(phrase) ? Icons.star : Icons.star_border,
                                          color: isTopPhrase(phrase) ? Colors.orange : Colors.grey,
                                        ),
                                        tooltip: "Pin to Top (Max 10)",
                                        onPressed: () {
                                          final success = toggleTopPhrase(phrase, !isTopPhrase(phrase));
                                          if (!success) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text("You can only pin up to 10 top phrases."), backgroundColor: Colors.orange),
                                            );
                                          } else {
                                            setState(() {});
                                          }
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.red),
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
            color: Colors.purple.shade50,
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
                      label: const Text('Global Bank'),
                      onPressed: _showGlobalThemeImportDialog,
                    ),
                  ],
                ),
                const Text('Drag a theme to the calendar to schedule it.', style: TextStyle(color: Colors.grey)),
                const Divider(),
                Expanded(
                  child: allThemes.isEmpty 
                    ? const Center(child: Text("Create themes in Word Setup first."))
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
                                decoration: BoxDecoration(color: Colors.purple, borderRadius: BorderRadius.circular(8)),
                                child: Text(theme, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            childWhenDragging: Card(
                              color: Colors.grey.shade300,
                              child: ListTile(title: Text(theme, style: const TextStyle(color: Colors.grey))),
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
                                  leading: const Icon(Icons.drag_indicator, color: Colors.purple),
                                  title: Text(theme, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('$wordCount words: $wordPreview', maxLines: 2, overflow: TextOverflow.ellipsis),
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
                          setState(() {
                            addThemeToDate(targetDate, details.data);
                          });
                        },
                        builder: (context, candidateData, rejectedData) {
                          return Card(
                            color: candidateData.isNotEmpty ? Colors.blue.shade100 : Colors.white,
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
                                    const Text("No themes scheduled.", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))
                                  else
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: activeThemes.map((theme) {
                                        return Chip(
                                          label: Text(theme, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                          backgroundColor: Colors.blue,
                                          deleteIcon: const Icon(Icons.close, color: Colors.white, size: 18),
                                          onDeleted: () {
                                            setState(() {
                                              removeThemeFromDate(targetDate, theme);
                                            });
                                          },
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
                            color: isSelected ? Colors.blue.shade50 : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? Colors.blue : Colors.grey.shade300, 
                              width: isSelected ? 2 : 1
                            ),
                            boxShadow: [
                              if (!isSelected) const BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1))
                            ],
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center, 
                              children: [
                                Icon(icon, color: isSelected ? Colors.blue.shade900 : Colors.grey.shade600), 
                                const SizedBox(width: 8), 
                                Text(
                                  text, 
                                  style: TextStyle(
                                    fontSize: 16, 
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.blue.shade900 : Colors.grey.shade700,
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
        body: TabBarView(
          children: [
            _buildThemeSchedulerTab(),
            _buildWordSetupTab(),
            _buildPhrasebookTab(),
          ],
        ),
      ),
    );
  }
}
