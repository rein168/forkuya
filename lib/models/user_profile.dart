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
  LWWSet customImages = LWWSet();

  Map<String, int> phraseAccessCount = {};
  Map<String, int> themeAccessCount = {};
  Map<String, int> wordAccessCount = {};
  List<String> typingHistory = [];

  String voicePreference = 'WOMAN';
  String offlineEngine = 'piper';
  bool ttsEnabled = false;
  // Typeface for the whole app; one of the options in design_tokens' docs
  // (Fredoka, Lexend, Andika). See DESIGN.md typography rules.
  String fontPreference = 'Fredoka';
  // Auto-collapse the on-screen keyboard once a physical keyboard is used.
  bool autoHideKeyboard = true;
  // The built-in Teacher profile; never deletable and gets teacher affordances.
  bool isTeacher = false;
  // Unfinished Free Typing text, restored when the student comes back.
  String draftText = '';

  UserProfile({required this.id, required this.name, this.avatar = 'fox'});

  void merge(UserProfile other) {
    phrasebook.merge(other.phrasebook);
    wordsByTheme.merge(other.wordsByTheme);
    activePhrases.merge(other.activePhrases);
    topPhrases.merge(other.topPhrases);
    activeThemesByDate.merge(other.activeThemesByDate);
    customImages.merge(other.customImages);

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
    'customImages': customImages.toJson(),
    'phraseAccessCount': phraseAccessCount,
    'themeAccessCount': themeAccessCount,
    'wordAccessCount': wordAccessCount,
    'typingHistory': typingHistory,
    'voicePreference': voicePreference,
    'offlineEngine': offlineEngine,
    'ttsEnabled': ttsEnabled,
    'fontPreference': fontPreference,
    'autoHideKeyboard': autoHideKeyboard,
    'draftText': draftText,
    'isTeacher': isTeacher,
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
    if (json['customImages'] != null) p.customImages = LWWSet.fromJson(json['customImages']);

    p.phraseAccessCount = Map<String, int>.from(json['phraseAccessCount'] ?? {});
    p.themeAccessCount = Map<String, int>.from(json['themeAccessCount'] ?? {});
    p.wordAccessCount = Map<String, int>.from(json['wordAccessCount'] ?? {});

    p.typingHistory = List<String>.from(json['typingHistory'] ?? []);
    p.voicePreference = json['voicePreference'] ?? 'WOMAN';
    p.offlineEngine = json['offlineEngine'] ?? 'piper';
    p.ttsEnabled = json['ttsEnabled'] ?? false;
    p.fontPreference = json['fontPreference'] ?? 'Fredoka';
    p.autoHideKeyboard = json['autoHideKeyboard'] ?? true;
    p.draftText = json['draftText'] ?? '';
    // Older profiles never stored the flag; fall back to the legacy
    // name-based rule so existing Teacher profiles stay recognized.
    p.isTeacher = json['isTeacher'] ?? ((json['name'] ?? '') == 'Teacher');
    p.avatar = json['avatar'] ?? 'fox';
    return p;
  }
}

