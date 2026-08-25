import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_io/io.dart';

import 'profile_store.dart';

/// File-based profile backups. Not supported on web (no filesystem);
/// callers should hide these actions when [backupsSupported] is false.
bool get backupsSupported => !kIsWeb;

Future<Directory> _backupDirectory() async {
  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory('${docs.path}${Platform.pathSeparator}Typer');
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  return dir;
}

String _safeFileName(String name) {
  final cleaned = name.replaceAll(RegExp(r'[^A-Za-z0-9_\- ]'), '').trim();
  return cleaned.isEmpty ? 'profile' : cleaned.replaceAll(' ', '_');
}

String _timestamp() {
  final now = DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}';
}

/// Writes the current profile to a JSON file and returns the full path.
Future<String> exportCurrentProfileToFile() async {
  final dir = await _backupDirectory();
  final file = File(
      '${dir.path}${Platform.pathSeparator}TyperProfile_${_safeFileName(currentProfile.name)}_${_timestamp()}.json');
  await file.writeAsString(exportCurrentProfileJSON());
  return file.path;
}

/// Silently snapshots a profile before a destructive action (delete or
/// overwrite-import) so the data can be recovered by importing the file.
Future<void> autoBackupProfile(String id, String reason) async {
  if (!backupsSupported) return;
  try {
    final profile = getProfileInfo(id);
    if (profile == null) return;
    final dir = await _backupDirectory();
    final file = File(
        '${dir.path}${Platform.pathSeparator}AutoBackup_${reason}_${_safeFileName(profile.name)}_${_timestamp()}.json');
    await file.writeAsString(jsonEncode(profile.toJson()));
  } catch (e) {
    debugPrint('Auto-backup failed: $e');
  }
}

/// Lists saved backup/export files, newest first.
Future<List<File>> listProfileBackupFiles() async {
  final dir = await _backupDirectory();
  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.toLowerCase().endsWith('.json'))
      .toList();
  files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
  return files;
}

Future<String> readBackupFile(File file) => file.readAsString();
