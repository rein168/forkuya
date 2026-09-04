import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_profile.dart';

late SharedPreferences _prefs;

// --- MULTI-PROFILE GLOBALS ---
List<String> availableProfileIds = [];
String currentProfileId = "default";
late UserProfile currentProfile;

const List<String> _defaultPhrases = ["I want to eat", "I want to play", "Yes", "No"];

Future<void> initGlobals() async {
  _prefs = await SharedPreferences.getInstance();
  availableProfileIds = _prefs.getStringList('typer_profile_ids') ?? [];
  currentProfileId = _prefs.getString('typer_last_profile_id') ?? 'default';

  // Wipe any previously saved API keys from storage for security
  await _prefs.remove('google_api_key');

  if (availableProfileIds.isEmpty) {
    // First time launch: Migrate legacy data into a 'default' profile
    availableProfileIds.add('default');
    currentProfile = UserProfile(id: 'default', name: 'Teacher')..isTeacher = true;
    _migrateLegacyData();
    _ensureProfileDefaults(currentProfile);
    fontPreferenceNotifier.value = currentProfile.fontPreference;
    await _saveCurrentProfile();
    await _prefs.setStringList('typer_profile_ids', availableProfileIds);
  } else {
    await loadProfile(currentProfileId);
  }
}

/// Seeds starter phrases on profiles that have never had any, and activates
/// all phrases on profiles created before active/inactive toggling existed.
/// Runs outside of build so getters can stay side-effect free.
void _ensureProfileDefaults(UserProfile profile) {
    final mergeKey = 'starter_pack_merged_${profile.id}';
    final hasMerged = _prefs.getBool(mergeKey) ?? false;
    if (!hasMerged) {
      final starterThemes = {
        'Core Words': ['MORE', 'DONE', 'HELP', 'STOP', 'GO', 'YES', 'NO', 'WANT', 'LIKE'],
        'Animals': ['DOG', 'CAT', 'BIRD', 'FISH', 'COW', 'PIG', 'HORSE', 'FROG', 'LION', 'BEAR'],
        'Food': ['APPLE', 'BANANA', 'COOKIE', 'MILK', 'WATER', 'BREAD', 'PIZZA', 'CHEESE', 'JUICE', 'CRACKER'],
        'Colors': ['RED', 'BLUE', 'GREEN', 'YELLOW', 'BLACK', 'WHITE', 'ORANGE', 'PURPLE', 'PINK', 'BROWN'],
        'Toys': ['BALL', 'CAR', 'DOLL', 'BLOCK', 'BOOK', 'PUZZLE', 'BUBBLES', 'TRAIN', 'TEDDY'],
        'Body Parts': ['EYES', 'EARS', 'NOSE', 'MOUTH', 'HANDS', 'FEET', 'HEAD', 'HAIR']
      };
      starterThemes.forEach((theme, words) {
        profile.wordsByTheme.add("$theme||__DUMMY__");
        for (var word in words) {
          profile.wordsByTheme.add("$theme||$word");
        }
      });
      _prefs.setBool(mergeKey, true);
    }
  if (profile.phrasebook.additions.isEmpty) {
    for (var phrase in _defaultPhrases) {
      profile.phrasebook.add(phrase);
    }
  }
  if (profile.activePhrases.additions.isEmpty) {
    for (var phrase in profile.phrasebook.activeElements) {
      profile.activePhrases.add(phrase);
    }
  }
}

void _migrateLegacyData() {
  // Try to load old legacy SharedPreferences and migrate them into currentProfile
  // Words by Theme
  final String? wordsJson = _prefs.getString('typer_words_by_theme');
  if (wordsJson != null) {
    try {
      final Map<String, dynamic> decoded = jsonDecode(wordsJson);
      decoded.forEach((theme, words) {
        currentProfile.wordsByTheme.add("$theme||__DUMMY__");
        for (var word in List<String>.from(words)) {
          currentProfile.wordsByTheme.add("$theme||$word");
        }
      });
    } catch (_) {}
  }

  // Active Themes by Date
  final String? activeThemeJson = _prefs.getString('typer_active_theme_by_date');
  if (activeThemeJson != null) {
    try {
      final Map<String, dynamic> decoded = jsonDecode(activeThemeJson);
      decoded.forEach((date, themes) {
        for (var theme in List<String>.from(themes)) {
          currentProfile.activeThemesByDate.add("$date||$theme");
        }
      });
    } catch (_) {}
  }

  currentProfile.voicePreference = _prefs.getString('typer_voice_preference') ?? 'WOMAN';
  currentProfile.offlineEngine = _prefs.getString('typer_offline_engine') ?? 'piper';
  currentProfile.typingHistory = _prefs.getStringList('typer_typing_history') ?? [];

  for (var phrase in _prefs.getStringList('typer_phrasebook') ?? []) {
    currentProfile.phrasebook.add(phrase);
  }
  for (var phrase in _prefs.getStringList('typer_active_phrases') ?? []) {
    currentProfile.activePhrases.add(phrase);
  }
  for (var phrase in _prefs.getStringList('typer_top_phrases') ?? []) {
    currentProfile.topPhrases.add(phrase);
  }

  final String? phraseCountJson = _prefs.getString('typer_phrase_access_count');
  if (phraseCountJson != null) {
    try { currentProfile.phraseAccessCount = Map<String, int>.from(jsonDecode(phraseCountJson)); } catch (_) {}
  }

  final String? themeCountJson = _prefs.getString('typer_theme_access_count');
  if (themeCountJson != null) {
    try { currentProfile.themeAccessCount = Map<String, int>.from(jsonDecode(themeCountJson)); } catch (_) {}
  }

  final String? wordCountJson = _prefs.getString('typer_word_access_count');
  if (wordCountJson != null) {
    try { currentProfile.wordAccessCount = Map<String, int>.from(jsonDecode(wordCountJson)); } catch (_) {}
  }

  currentProfile.ttsEnabled = _prefs.getBool('typer_tts_enabled') ?? false;
}

Future<void> loadProfile(String id) async {
  currentProfileId = id;
  await _prefs.setString('typer_last_profile_id', id);

  final profileJsonStr = _prefs.getString('typer_profile_$id');
  if (profileJsonStr != null) {
    try {
      currentProfile = UserProfile.fromJson(jsonDecode(profileJsonStr));
    } catch (_) {
      currentProfile = UserProfile(id: id, name: 'Teacher');
    }
  } else {
    currentProfile = UserProfile(id: id, name: 'Teacher');
  }
  _ensureProfileDefaults(currentProfile);
  fontPreferenceNotifier.value = currentProfile.fontPreference;
  await _saveCurrentProfile();
}

// Saves are chained so concurrent unawaited calls can never interleave and
// write a stale snapshot over a newer one. Failures are surfaced through
// [profileSaveFailed] because callers are fire-and-forget — a silent data-
// loss path was unacceptable for this app's users.
final ValueNotifier<bool> profileSaveFailed = ValueNotifier(false);
Future<void> _lastSave = Future.value();

Future<void> _saveCurrentProfile() {
  _lastSave = _lastSave.then((_) async {
    try {
      await _prefs.setString('typer_profile_$currentProfileId', jsonEncode(currentProfile.toJson()));
      profileSaveFailed.value = false;
    } catch (e) {
      debugPrint("Profile save failed: $e");
      profileSaveFailed.value = true;
    }
  });
  return _lastSave;
}

/// Re-runs the pending save after the user taps Retry on the banner.
Future<void> retryProfileSave() async {
  await _saveCurrentProfile();
  await _lastSave;
}

Future<void> saveCurrentProfile() => _saveCurrentProfile();

// --- FREE TYPING DRAFT ---
Timer? _draftSaveTimer;

String getDraftText() => currentProfile.draftText;

/// Updates the in-memory draft immediately and persists it with a short
/// debounce so rapid keystrokes don't hammer storage.
void setDraftText(String text) {
  currentProfile.draftText = text;
  _draftSaveTimer?.cancel();
  _draftSaveTimer = Timer(const Duration(milliseconds: 800), () {
    _saveCurrentProfile();
  });
}

/// Persists the pending draft now (back navigation, app paused).
Future<void> flushDraftText() async {
  _draftSaveTimer?.cancel();
  await _saveCurrentProfile();
}

Future<void> createNewProfile(String name, String avatar) async {
  String id = DateTime.now().millisecondsSinceEpoch.toString();
  availableProfileIds.add(id);
  await _prefs.setStringList('typer_profile_ids', availableProfileIds);
  currentProfile = UserProfile(id: id, name: name, avatar: avatar);
  _ensureProfileDefaults(currentProfile);
  currentProfileId = id;
  await _saveCurrentProfile();
  await loadProfile(id);
}

Future<void> deleteProfile(String id) async {
  availableProfileIds.remove(id);
  await _prefs.setStringList('typer_profile_ids', availableProfileIds);
  await _prefs.remove('typer_profile_$id');
  if (currentProfileId == id && availableProfileIds.isNotEmpty) {
    await loadProfile(availableProfileIds.first);
  }
}

UserProfile? getProfileInfo(String id) {
  final str = _prefs.getString('typer_profile_$id');
  if (str != null) {
    try {
      return UserProfile.fromJson(jsonDecode(str));
    } catch (_) {}
  }
  return null;
}

String exportCurrentProfileJSON() {
  return jsonEncode(currentProfile.toJson());
}

Future<bool> importAndMergeProfileJSON(String jsonStr, {bool overwrite = false}) async {
  try {
    var imported = UserProfile.fromJson(jsonDecode(jsonStr));

    // Check if profile exists
    if (!availableProfileIds.contains(imported.id)) {
      availableProfileIds.add(imported.id);
      await _prefs.setStringList('typer_profile_ids', availableProfileIds);
      currentProfileId = imported.id;
      currentProfile = imported;
    } else {
      currentProfileId = imported.id;
      if (!overwrite) {
        // Load local version first
        await loadProfile(imported.id);
        // Merge the incoming imported version into local
        currentProfile.merge(imported);
      } else {
        currentProfile = imported;
      }
    }

    _ensureProfileDefaults(currentProfile);
    await _saveCurrentProfile();
    await _prefs.setString('typer_last_profile_id', currentProfileId);
    return true;
  } catch (e) {
    debugPrint("Import Error: $e");
    return false;
  }
}


// --- PUBLIC API FOR APP (Adapters to CRDT) ---

String formatDate(DateTime date) {
  return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
}

List<String> getAvailableThemes() {
  Set<String> themes = {};
  for (var entry in currentProfile.wordsByTheme.activeElements) {
    var parts = entry.split("||");
    if (parts.isNotEmpty) themes.add(parts[0]);
  }
  return themes.toList();
}

int getThemeAccessCount(String theme) => currentProfile.themeAccessCount[theme] ?? 0;
int getWordAccessCount(String word) => currentProfile.wordAccessCount[word] ?? 0;

void incrementWordAccessCount(String word) {
  currentProfile.wordAccessCount[word] = getWordAccessCount(word) + 1;
  _saveCurrentProfile();
}

void incrementThemeAccessCount(String theme) {
  if (theme.isNotEmpty) {
    currentProfile.themeAccessCount[theme] = getThemeAccessCount(theme) + 1;
    _saveCurrentProfile();
  }
}

List<String> getActiveThemesForDate(DateTime date) {
  final dateKey = formatDate(date);
  List<String> themes = [];
  for (var entry in currentProfile.activeThemesByDate.activeElements) {
    if (entry.startsWith("$dateKey||")) {
      themes.add(entry.split("||")[1]);
    }
  }
  return themes;
}

void addThemeToDate(DateTime date, String theme) {
  final dateKey = formatDate(date);
  currentProfile.activeThemesByDate.add("$dateKey||$theme");
  _saveCurrentProfile();
}

void removeThemeFromDate(DateTime date, String theme) {
  final dateKey = formatDate(date);
  currentProfile.activeThemesByDate.remove("$dateKey||$theme");
  _saveCurrentProfile();
}

List<String> getWordsForTheme(String theme) {
  List<String> words = [];
  for (var entry in currentProfile.wordsByTheme.activeElements) {
    var parts = entry.split("||");
    if (parts.length > 1 && parts[0] == theme && parts[1] != "__DUMMY__") {
      words.add(parts[1]);
    }
  }
  return words;
}

List<String> getWordsForDate(DateTime date) {
  final themes = getActiveThemesForDate(date);
  if (themes.isNotEmpty) {
    List<String> combinedWords = [];
    for (String theme in themes) {
      combinedWords.addAll(getWordsForTheme(theme));
    }
    return combinedWords.toSet().toList();
  }
  return ['CAT', 'DOG', 'BIRD']; // Fallback
}

void createTheme(String theme) {
  currentProfile.wordsByTheme.add("$theme||__DUMMY__");
  _saveCurrentProfile();
}

void addWordToTheme(String theme, String word) {
  currentProfile.wordsByTheme.add("$theme||$word");
  _saveCurrentProfile();
}

void removeWordFromTheme(String theme, String word) {
  currentProfile.wordsByTheme.remove("$theme||$word");
  _saveCurrentProfile();
}

/// Deletes a theme together with all its words and any dates it was
/// scheduled on. Entries are tombstoned so stale Profile Codes or backups
/// cannot resurrect them.
void deleteTheme(String theme) {
  for (final entry in List<String>.from(currentProfile.wordsByTheme.activeElements)) {
    if (entry.split("||").first == theme) {
      currentProfile.wordsByTheme.remove(entry);
    }
  }
  for (final entry in List<String>.from(currentProfile.activeThemesByDate.activeElements)) {
    final parts = entry.split("||");
    if (parts.length > 1 && parts[1] == theme) {
      currentProfile.activeThemesByDate.remove(entry);
    }
  }
  _saveCurrentProfile();
}

/// Renames a theme, carrying its words and its scheduled dates over.
void renameTheme(String oldName, String newName) {
  final clean = newName.trim().toUpperCase();
  if (clean.isEmpty || clean == oldName) return;

  for (final entry in List<String>.from(currentProfile.wordsByTheme.activeElements)) {
    final parts = entry.split("||");
    if (parts.isNotEmpty && parts[0] == oldName) {
      final word = parts.length > 1 ? parts[1] : "__DUMMY__";
      currentProfile.wordsByTheme.remove(entry);
      currentProfile.wordsByTheme.add("$clean||$word");
    }
  }
  for (final entry in List<String>.from(currentProfile.activeThemesByDate.activeElements)) {
    final parts = entry.split("||");
    if (parts.length > 1 && parts[1] == oldName) {
      currentProfile.activeThemesByDate.remove(entry);
      currentProfile.activeThemesByDate.add("${parts[0]}||$clean");
    }
  }
  _saveCurrentProfile();
}

// --- VOICE & TTS PREFERENCES ---
String getVoicePreference() => currentProfile.voicePreference;
String getOfflineEngine() => currentProfile.offlineEngine;

/// Notifies MaterialApp when the typeface changes so the whole app re-renders.
final ValueNotifier<String> fontPreferenceNotifier = ValueNotifier('Fredoka');

/// The typefaces the app can render; anything else normalizes to Fredoka.
const Set<String> supportedFonts = {'Fredoka', 'Lexend', 'Andika'};

String getFontPreference() => currentProfile.fontPreference;

Future<void> setFontPreference(String font) async {
  currentProfile.fontPreference = supportedFonts.contains(font) ? font : 'Fredoka';
  fontPreferenceNotifier.value = currentProfile.fontPreference;
  await _saveCurrentProfile();
}

Future<void> setVoicePreference(String voice) async {
  currentProfile.voicePreference = voice;
  await _saveCurrentProfile();
  await _prefs.setString('typer_voice_preference', voice);
}

Future<void> setOfflineEngine(String engine) async {
  currentProfile.offlineEngine = engine;
  await _saveCurrentProfile();
  await _prefs.setString('typer_offline_engine', engine);
}

bool getTtsEnabled() => currentProfile.ttsEnabled;

Future<void> setTtsEnabled(bool enabled) async {
  currentProfile.ttsEnabled = enabled;
  await _saveCurrentProfile();
}

// --- ON-SCREEN KEYBOARD ---
bool getAutoHideKeyboard() => currentProfile.autoHideKeyboard;

Future<void> setAutoHideKeyboard(bool enabled) async {
  currentProfile.autoHideKeyboard = enabled;
  await _saveCurrentProfile();
}

// --- SPEAK BUTTON LABEL ---
bool getSpeakButtonIconOnly() => currentProfile.speakButtonIconOnly;

Future<void> setSpeakButtonIconOnly(bool iconOnly) async {
  currentProfile.speakButtonIconOnly = iconOnly;
  await _saveCurrentProfile();
}

// --- OFFLINE VOICE (PIPER, WEB) ---
// Device-wide (not per-profile): whether to load and prefer the bundled
// offline Piper neural voice. ON by default — works fully offline, ~63 MB
// one-time download then cached. Teachers can turn it off in Settings.
bool getOfflineVoiceEnabled() => _prefs.getBool('typer_offline_voice') ?? true;

Future<void> setOfflineVoiceEnabled(bool enabled) async {
  await _prefs.setBool('typer_offline_voice', enabled);
}

// --- FREE TYPING HISTORY (ANALYTICS) ---
List<String> getTypingHistory() => currentProfile.typingHistory;

void logTypedSentence(String sentence) {
  final clean = sentence.trim();
  if (clean.isNotEmpty) {
    if (currentProfile.typingHistory.length >= 50) currentProfile.typingHistory.removeAt(0);
    currentProfile.typingHistory.add(clean);
    _saveCurrentProfile();
  }
}

void processFreeTypedSentence(String sentence) {
  final clean = sentence.trim();
  if (clean.isEmpty) return;
  final sentenceCase = _toSentenceCase(clean);

  if (getPhrasebook().contains(sentenceCase)) {
    incrementPhraseAccessCount(sentenceCase);
  } else {
    logTypedSentence(clean);
  }
}

void clearTypingHistory() {
  currentProfile.typingHistory.clear();
  _saveCurrentProfile();
}

void removeTypedSentence(String sentence) {
  currentProfile.typingHistory.remove(sentence);
  _saveCurrentProfile();
}

// --- PHRASEBOOK ---
List<String> getPhrasebook() => currentProfile.phrasebook.activeElements;

List<String> getActivePhrases() => currentProfile.activePhrases.activeElements
    .where((p) => currentProfile.phrasebook.activeElements.contains(p))
    .toList();

void togglePhraseActive(String phrase, bool isActive) {
  if (isActive) {
    currentProfile.activePhrases.add(phrase);
  } else {
    currentProfile.activePhrases.remove(phrase);
  }
  _saveCurrentProfile();
}

bool isPhraseActive(String phrase) {
  return currentProfile.activePhrases.activeElements.contains(phrase);
}

int getPhraseAccessCount(String phrase) => currentProfile.phraseAccessCount[phrase] ?? 0;

void incrementPhraseAccessCount(String phrase) {
  if (phrase.isNotEmpty) {
    currentProfile.phraseAccessCount[phrase] = getPhraseAccessCount(phrase) + 1;
    _saveCurrentProfile();
  }
}

String _toSentenceCase(String text) {
  if (text.isEmpty) return text;
  return text[0].toUpperCase() + text.substring(1).toLowerCase();
}

void addPhrase(String phrase) {
  final clean = _toSentenceCase(phrase.trim());
  if (clean.isEmpty) return;

  if (!currentProfile.phrasebook.activeElements.contains(clean)) {
    currentProfile.phrasebook.add(clean);
    currentProfile.activePhrases.add(clean);
    _saveCurrentProfile();
  }
}

void removePhrase(String phrase) {
  currentProfile.phrasebook.remove(phrase);
  currentProfile.activePhrases.remove(phrase);
  _saveCurrentProfile();
}

void editPhrase(String oldPhrase, String newPhrase) {
  final clean = newPhrase.trim();
  if (clean.isEmpty || clean == oldPhrase) return;

  if (currentProfile.phrasebook.activeElements.contains(oldPhrase)) {
    currentProfile.phrasebook.remove(oldPhrase);
    currentProfile.phrasebook.add(clean);
  }

  if (currentProfile.activePhrases.activeElements.contains(oldPhrase)) {
    currentProfile.activePhrases.remove(oldPhrase);
    currentProfile.activePhrases.add(clean);
  }

  if (currentProfile.phraseAccessCount.containsKey(oldPhrase)) {
    currentProfile.phraseAccessCount[clean] = currentProfile.phraseAccessCount[oldPhrase]!;
    currentProfile.phraseAccessCount.remove(oldPhrase);
  }
  _saveCurrentProfile();
}

// --- TOP PHRASES ---
List<String> getTopPhrases() {
  return currentProfile.topPhrases.activeElements;
}

bool toggleTopPhrase(String phrase, bool isTop) {
  if (isTop) {
    if (currentProfile.topPhrases.activeElements.length >= 10 && !currentProfile.topPhrases.activeElements.contains(phrase)) {
      return false; // Can't add more than 10
    }
    currentProfile.topPhrases.add(phrase);
  } else {
    currentProfile.topPhrases.remove(phrase);
  }
  _saveCurrentProfile();
  return true;
}

bool isTopPhrase(String phrase) {
  return currentProfile.topPhrases.activeElements.contains(phrase);
}

// --- GLOBAL BANK (themes and phrases shared between profiles on this device) ---
class GlobalThemeInfo {
  final String themeName;
  final String profileId;
  final String profileName;
  final Set<String> words;
  GlobalThemeInfo(this.themeName, this.profileId, this.profileName, this.words);
}

List<GlobalThemeInfo> getGlobalThemeBank() {
  List<GlobalThemeInfo> globalBank = [];
  for (String id in availableProfileIds) {
    UserProfile? profile = getProfileInfo(id);
    if (profile != null) {
      Map<String, Set<String>> themesForProfile = {};
      for (var entry in profile.wordsByTheme.activeElements) {
         var parts = entry.split("||");
         if (parts.length > 1) {
            String theme = parts[0];
            String word = parts[1];
            themesForProfile.putIfAbsent(theme, () => {});
            if (word != "__DUMMY__") {
              themesForProfile[theme]!.add(word);
            }
         }
      }
      themesForProfile.forEach((theme, words) {
        globalBank.add(GlobalThemeInfo(theme, id, profile.name, words));
      });
    }
  }
  return globalBank;
}

Set<String> getGlobalPhraseBank() {
  Set<String> globalPhrases = {};
  for (String id in availableProfileIds) {
    UserProfile? profile = getProfileInfo(id);
    if (profile != null) {
      globalPhrases.addAll(profile.phrasebook.activeElements);
    }
  }
  return globalPhrases;
}

/// Removes every theme and phrase from ALL profiles on this device,
/// emptying the Global Bank. Elements are tombstoned, not deleted, so an
/// older Profile Code or backup merge cannot resurrect them. Typing
/// history and access counts are kept.
Future<void> wipeGlobalBank() async {
  for (String id in List<String>.from(availableProfileIds)) {
    final UserProfile? profile = id == currentProfileId ? currentProfile : getProfileInfo(id);
    if (profile == null) continue;
    profile.wordsByTheme.removeAll();
    profile.activeThemesByDate.removeAll();
      profile.customImages.removeAll();
    profile.phrasebook.removeAll();
    profile.activePhrases.removeAll();
    profile.topPhrases.removeAll();
    if (id == currentProfileId) {
      await _saveCurrentProfile();
    } else {
      await _prefs.setString('typer_profile_$id', jsonEncode(profile.toJson()));
    }
  }
}


