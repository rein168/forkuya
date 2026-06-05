
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_tts/flutter_tts.dart';

late SharedPreferences _prefs;

// --- MULTI-PROFILE GLOBALS ---
List<String> availableProfileIds = [];
String currentProfileId = "default";
late UserProfile currentProfile;

// --- GOOGLE CLOUD TTS SETTINGS ---
String currentGoogleApiKey = ''; // Loaded dynamically from SharedPreferences
final AudioPlayer _audioPlayer = AudioPlayer();
final FlutterTts _flutterTts = FlutterTts();

class LWWSet {
  Map<String, int> additions = {};
  Map<String, int> removals = {};

  LWWSet();

  List<String> get activeElements {
    return additions.keys.where((element) {
      final addTime = additions[element] ?? 0;
      final remTime = removals[element] ?? 0;
      return addTime > remTime;
    }).toList();
  }

  void add(String element, [int? timestamp]) {
    additions[element] = timestamp ?? DateTime.now().millisecondsSinceEpoch;
  }

  void remove(String element, [int? timestamp]) {
    removals[element] = timestamp ?? DateTime.now().millisecondsSinceEpoch;
  }
  
  void merge(LWWSet other) {
    other.additions.forEach((element, time) {
      if ((additions[element] ?? 0) < time) additions[element] = time;
    });
    other.removals.forEach((element, time) {
      if ((removals[element] ?? 0) < time) removals[element] = time;
    });
  }

  Map<String, dynamic> toJson() => {
    'additions': additions,
    'removals': removals,
  };

  factory LWWSet.fromJson(Map<String, dynamic> json) {
    var set = LWWSet();
    set.additions = Map<String, int>.from(json['additions'] ?? {});
    set.removals = Map<String, int>.from(json['removals'] ?? {});
    return set;
  }
}

class UserProfile {
  String id;
  String name;
  String avatar;
  
  LWWSet phrasebook = LWWSet();
  LWWSet wordsByTheme = LWWSet();
  LWWSet activePhrases = LWWSet();
  LWWSet topPhrases = LWWSet();
  LWWSet activeThemesByDate = LWWSet();
  
  Map<String, int> phraseAccessCount = {};
  Map<String, int> themeAccessCount = {};
  Map<String, int> wordAccessCount = {};
  List<String> typingHistory = [];
  
  String voicePreference = 'WOMAN';
  bool ttsEnabled = false;

  UserProfile({required this.id, required this.name, this.avatar = 'fox'});

  void merge(UserProfile other) {
    phrasebook.merge(other.phrasebook);
    wordsByTheme.merge(other.wordsByTheme);
    activePhrases.merge(other.activePhrases);
    topPhrases.merge(other.topPhrases);
    activeThemesByDate.merge(other.activeThemesByDate);

    other.phraseAccessCount.forEach((k, v) => phraseAccessCount[k] = max(phraseAccessCount[k] ?? 0, v));
    other.themeAccessCount.forEach((k, v) => themeAccessCount[k] = max(themeAccessCount[k] ?? 0, v));
    other.wordAccessCount.forEach((k, v) => wordAccessCount[k] = max(wordAccessCount[k] ?? 0, v));

    // Combine and limit history
    var combinedHistory = (typingHistory + other.typingHistory).toSet().toList();
    if (combinedHistory.length > 50) {
      combinedHistory = combinedHistory.sublist(combinedHistory.length - 50);
    }
    typingHistory = combinedHistory;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phrasebook': phrasebook.toJson(),
    'wordsByTheme': wordsByTheme.toJson(),
    'activePhrases': activePhrases.toJson(),
    'topPhrases': topPhrases.toJson(),
    'activeThemesByDate': activeThemesByDate.toJson(),
    'phraseAccessCount': phraseAccessCount,
    'themeAccessCount': themeAccessCount,
    'wordAccessCount': wordAccessCount,
    'typingHistory': typingHistory,
    'voicePreference': voicePreference,
    'ttsEnabled': ttsEnabled,
    'avatar': avatar,
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    var p = UserProfile(id: json['id'] ?? 'default', name: json['name'] ?? 'Teacher');
    String n = p.name.toLowerCase();
    if (n == 'unknown' || n == 'student' || n == 'new student' || n.isEmpty) {
      p.name = 'Teacher'; // Aggressively upgrade older default names
    }
    if (json['phrasebook'] != null) p.phrasebook = LWWSet.fromJson(json['phrasebook']);
    if (json['wordsByTheme'] != null) p.wordsByTheme = LWWSet.fromJson(json['wordsByTheme']);
    if (json['activePhrases'] != null) p.activePhrases = LWWSet.fromJson(json['activePhrases']);
    if (json['topPhrases'] != null) p.topPhrases = LWWSet.fromJson(json['topPhrases']);
    if (json['activeThemesByDate'] != null) p.activeThemesByDate = LWWSet.fromJson(json['activeThemesByDate']);
    
    p.phraseAccessCount = Map<String, int>.from(json['phraseAccessCount'] ?? {});
    p.themeAccessCount = Map<String, int>.from(json['themeAccessCount'] ?? {});
    p.wordAccessCount = Map<String, int>.from(json['wordAccessCount'] ?? {});
    
    p.typingHistory = List<String>.from(json['typingHistory'] ?? []);
    p.voicePreference = json['voicePreference'] ?? 'WOMAN';
    p.ttsEnabled = json['ttsEnabled'] ?? false;
    p.avatar = json['avatar'] ?? 'fox';
    return p;
  }
}

Future<void> initGlobals() async {
  _prefs = await SharedPreferences.getInstance();
  availableProfileIds = _prefs.getStringList('typer_profile_ids') ?? [];
  currentProfileId = _prefs.getString('typer_last_profile_id') ?? 'default';
  
  // Wipe any previously saved API keys from storage for security
  await _prefs.remove('google_api_key');
  currentGoogleApiKey = '';

  if (availableProfileIds.isEmpty) {
    // First time launch: Migrate legacy data into a 'default' profile
    availableProfileIds.add('default');
    currentProfile = UserProfile(id: 'default', name: 'Teacher');
    _migrateLegacyData();
    await _saveCurrentProfile();
    await _prefs.setStringList('typer_profile_ids', availableProfileIds);
  } else {
    await loadProfile(currentProfileId);
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
  currentProfile.typingHistory = _prefs.getStringList('typer_typing_history') ?? [];
  
  for (var phrase in _prefs.getStringList('typer_phrasebook') ?? []) currentProfile.phrasebook.add(phrase);
  for (var phrase in _prefs.getStringList('typer_active_phrases') ?? []) currentProfile.activePhrases.add(phrase);
  for (var phrase in _prefs.getStringList('typer_top_phrases') ?? []) currentProfile.topPhrases.add(phrase);
  
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
}

Future<void> _saveCurrentProfile() async {
  await _prefs.setString('typer_profile_$currentProfileId', jsonEncode(currentProfile.toJson()));
}

Future<void> createNewProfile(String name, String avatar) async {
  String id = DateTime.now().millisecondsSinceEpoch.toString();
  availableProfileIds.add(id);
  await _prefs.setStringList('typer_profile_ids', availableProfileIds);
  currentProfile = UserProfile(id: id, name: name, avatar: avatar);
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
    
    await _saveCurrentProfile();
    await _prefs.setString('typer_last_profile_id', currentProfileId);
    return true;
  } catch (e) {
    print("Import Error: $e");
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

// --- VOICE & TTS ---
String getVoicePreference() => currentProfile.voicePreference;

Future<void> setVoicePreference(String voice) async {
  currentProfile.voicePreference = voice;
  await _saveCurrentProfile();
}

bool getTtsEnabled() => currentProfile.ttsEnabled;

Future<void> setTtsEnabled(bool enabled) async {
  currentProfile.ttsEnabled = enabled;
  await _saveCurrentProfile();
}

Future<void> setGoogleApiKey(String key) async {
  currentGoogleApiKey = key;
  // Intentionally NOT saving to SharedPreferences so it gets deleted when the app closes
}

int _ttsRequestId = 0;

Future<void> speakWithGoogleCloud(String text) async {
  if (text.trim().isEmpty) return;
  
  final int currentRequestId = ++_ttsRequestId;
  
  String voiceCode;
  double pitch = 0.0;
  double localPitch = 1.0;
  
  switch (currentProfile.voicePreference) {
    case 'BOY':
      voiceCode = 'en-US-Neural2-D';
      pitch = 6.0;
      localPitch = 2.0; // Very high
      break;
    case 'MAN':
      voiceCode = 'en-US-Neural2-D'; 
      pitch = -2.0;
      localPitch = 0.5; // Very low
      break;
    case 'GIRL':
      voiceCode = 'en-US-Neural2-F';
      pitch = 6.0;
      localPitch = 1.5; // High
      break;
    case 'WOMAN':
    default:
      voiceCode = 'en-US-Neural2-F';
      pitch = 0.0;
      localPitch = 1.0; // Normal
      break;
  }

  if (!currentProfile.ttsEnabled || currentGoogleApiKey.isEmpty) {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5); 
    await _flutterTts.setPitch(localPitch);
    await _flutterTts.speak(text);
    return;
  }

  final url = Uri.parse('https://texttospeech.googleapis.com/v1/text:synthesize?key=$currentGoogleApiKey');
  final payload = {
    'input': {'text': text},
    'voice': {'languageCode': 'en-US', 'name': voiceCode},
    'audioConfig': {'audioEncoding': 'MP3', 'pitch': pitch}
  };

  try {
    final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode(payload));
    if (currentRequestId != _ttsRequestId) return;

    if (response.statusCode == 200) {
      final audioBase64 = jsonDecode(response.body)['audioContent'];
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource('data:audio/mp3;base64,$audioBase64'));
    } else {
      // API Key might be invalid or quota exceeded. Fallback to local TTS!
      print("Google API Error: ${response.statusCode}");
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setPitch(localPitch);
      await _flutterTts.speak(text);
    }
  } catch (e) {
    // Network error (no internet). Fallback to local TTS!
    print("TTS Network Error: $e");
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setPitch(localPitch);
    await _flutterTts.speak(text);
  }
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
List<String> getPhrasebook() {
  var p = currentProfile.phrasebook.activeElements;
  if (p.isEmpty) {
    currentProfile.phrasebook.add("I want to eat");
    currentProfile.phrasebook.add("I want to play");
    currentProfile.phrasebook.add("Yes");
    currentProfile.phrasebook.add("No");
    _saveCurrentProfile();
    return ["I want to eat", "I want to play", "Yes", "No"];
  }
  return p;
}

List<String> getActivePhrases() {
  var a = currentProfile.activePhrases.activeElements;
  if (a.isEmpty) return getPhrasebook(); 
  return a;
}

void togglePhraseActive(String phrase, bool isActive) {
  if (isActive) {
    currentProfile.activePhrases.add(phrase);
  } else {
    currentProfile.activePhrases.remove(phrase);
  }
  _saveCurrentProfile();
}

bool isPhraseActive(String phrase) {
  var a = currentProfile.activePhrases.activeElements;
  return a.contains(phrase) || a.isEmpty;
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
  
  if (currentProfile.phrasebook.activeElements.isEmpty) {
    getPhrasebook(); // Initializes defaults
  }
  
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

// --- GLOBAL BANK ---
class GlobalThemeInfo {
  final String themeName;
  final String profileName;
  final Set<String> words;
  GlobalThemeInfo(this.themeName, this.profileName, this.words);
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
        globalBank.add(GlobalThemeInfo(theme, profile.name, words));
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

