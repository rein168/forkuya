import 'dart:math';

import 'lww_set.dart';

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
  // Auto-collapse the on-screen keyboard once a physical keyboard is used.
  bool autoHideKeyboard = true;

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
    'autoHideKeyboard': autoHideKeyboard,
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
    p.autoHideKeyboard = json['autoHideKeyboard'] ?? true;
    p.avatar = json['avatar'] ?? 'fox';
    return p;
  }
}
