import 'package:flutter/material.dart';

/// Typer design tokens — the single source of truth for what colors MEAN.
/// Documented in DESIGN.md; never use raw `Colors.*` in screens. If a new
/// meaning is needed, add a token here and to DESIGN.md, not a literal.
abstract final class TyperColors {
  // --- Activity accents: one pair per student activity ---
  static const Color wordsBg = Color(0xFFC5E1A5); // lightGreen.shade200
  static const Color wordsInk = Color(0xFF33691E); // lightGreen.shade900
  static const Color phrasesBg = Color(0xFFCE93D8); // purple.shade200
  static const Color phrasesWash = Color(0xFFF3E5F5); // purple.shade50
  static const Color phrasesBorder = Color(0xFFE1BEE7); // purple.shade100
  static const Color phrasesInk = Color(0xFF4A148C); // purple.shade900
  static const Color freeTypingBg = Color(0xFFFFF59D); // yellow.shade200
  static const Color freeTypingInk = Color(0xFFE65100); // orange.shade900

  /// Pastel rotation for student profile cards.
  static const List<Color> profileCardPalette = [
    Color(0xFFFCE4EC), // pink.shade50
    Color(0xFFFFF3E0), // orange.shade50
    Color(0xFFFFFDE7), // yellow.shade50
    Color(0xFFF3E5F5), // purple.shade50
    Color(0xFFE0F7FA), // cyan.shade50
  ];
  static const Color teacherCardBg = Color(0xFFDCEDC8); // lightGreen.shade100
  static const Color teacherAvatarBg = Color(0xFFAED581); // lightGreen.shade300

  // --- Semantic feedback ---
  static const Color speakBlue = Color(0xFF2196F3);
  static const Color correct = Color(0xFF388E3C); // green.shade700
  static const Color correctDeep = Color(0xFF2E7D32); // green.shade800
  static const Color incorrect = Color(0xFFD32F2F); // red.shade700
  static const Color destructive = Colors.red;
  static const Color warningSurface = Color(0xFFFFE0B2); // orange.shade100
  static const Color warningInk = Color(0xFFE65100); // orange.shade900

  // --- Ink & surfaces ---
  static const Color inkSecondary = Color(0xFF616161); // grey.shade700
  static const Color hairline = Color(0xFFE0E0E0); // grey.shade300
  static const Color borderStrong = Color(0xFFBDBDBD); // grey.shade400
  static const Color surfaceAlt = Color(0xFFF5F5F5); // grey.shade100
  static const Color surfaceSunken = Color(0xFFEEEEEE); // grey.shade200

  /// Placeholder backing for student avatars before the image loads.
  static const Color avatarPlaceholder = Color(0xB3FFFFFF); // Colors.white70

  // --- Selection & scroll accents (Speak Blue family) ---
  static const Color selectionWash = Color(0xFFE3F2FD); // blue.shade50
  static const Color selectionHover = Color(0xFFBBDEFB); // blue.shade100
  static const Color scrollThumb = Color(0xFF64B5F6); // blue.shade300
  static const Color selectionDeep = Color(0xFF0D47A1); // blue.shade900

  // --- Warning support ---
  static const Color warningBorder = Color(0xFFFFCCBC); // orange.shade200
}
