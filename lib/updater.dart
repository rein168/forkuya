import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:universal_io/io.dart';

const String githubRepo = 'rein168/forkuya';

/// In-app OTA updates only exist for the Windows installer build.
/// Android users get new APKs from the Releases page; web auto-deploys.
bool get updatesSupported => !kIsWeb && Platform.isWindows;

class UpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final String downloadUrl;
  final String? checksumUrl;

  UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.downloadUrl,
    this.checksumUrl,
  });

  /// True when the release publishes a .sha256 asset we can verify against.
  bool get hasChecksum => checksumUrl != null;
}

List<int> _parseVersion(String tag) {
  final cleaned = tag.trim().replaceFirst(RegExp(r'^v', caseSensitive: false), '');
  final parts = cleaned.split(RegExp(r'[.+-]')).map((p) => int.tryParse(p) ?? 0).toList();
  while (parts.length < 3) {
    parts.add(0);
  }
  return parts;
}

/// Numeric comparison so a rolled-back release doesn't get offered as an
/// "update", which a plain string inequality would do.
bool isNewerVersion(String latest, String current) {
  final l = _parseVersion(latest);
  final c = _parseVersion(current);
  final len = l.length > c.length ? l.length : c.length;
  for (var i = 0; i < len; i++) {
    final li = i < l.length ? l[i] : 0;
    final ci = i < c.length ? c[i] : 0;
    if (li != ci) return li > ci;
  }
  return false;
}

/// Checks GitHub for a newer release. Returns update details if one exists.
Future<UpdateInfo?> checkForUpdates() async {
  if (!updatesSupported) return null;
  try {
    final response = await http.get(Uri.parse('https://api.github.com/repos/$githubRepo/releases/latest'));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final latestTag = data['tag_name'] as String; // e.g. 'v1.0.1'

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = 'v${packageInfo.version}';

      debugPrint("Current Version: $currentVersion | Latest on GitHub: $latestTag");

      if (isNewerVersion(latestTag, currentVersion)) {
        final assets = data['assets'] as List;
        String? exeUrl;
        String? exeName;
        for (var asset in assets) {
          final fileName = asset['name'].toString();
          if (fileName.startsWith('Typer_Setup') && fileName.toLowerCase().endsWith('.exe')) {
            exeUrl = asset['browser_download_url'];
            exeName = fileName;
            break;
          }
        }
        if (exeUrl == null) return null;

        String? checksumUrl;
        for (var asset in assets) {
          final fileName = asset['name'].toString();
          if (fileName == '$exeName.sha256' ||
              (fileName.startsWith('Typer_Setup') && fileName.toLowerCase().endsWith('.sha256'))) {
            checksumUrl = asset['browser_download_url'];
            break;
          }
        }

        return UpdateInfo(
          currentVersion: currentVersion,
          latestVersion: latestTag,
          downloadUrl: exeUrl,
          checksumUrl: checksumUrl,
        );
      }
    }
  } catch (e) {
    debugPrint('Error checking for updates: $e');
  }
  return null;
}

Future<String> _fetchExpectedChecksum(String url) async {
  final response = await http.get(Uri.parse(url));
  if (response.statusCode != 200) {
    throw Exception('Could not download the update checksum (HTTP ${response.statusCode}).');
  }
  // Accept both a bare hash and the standard "<hash>  <filename>" format.
  final token = response.body.trim().split(RegExp(r'\s+')).first.toLowerCase();
  if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(token)) {
    throw Exception('The published checksum file is not a valid SHA-256 hash.');
  }
  return token;
}

/// Downloads the installer to the Windows temp folder, verifies its SHA-256
/// hash against the published checksum when one exists, then launches it.
Future<void> downloadAndInstallUpdate(UpdateInfo info, Function(double) onProgress) async {
  if (!updatesSupported) return;

  final savePath = '${Directory.systemTemp.path}${Platform.pathSeparator}Typer_Setup_Update.exe';
  final file = File(savePath);

  try {
    final client = HttpClient();
    final request = await client.getUrl(Uri.parse(info.downloadUrl));
    final response = await request.close();

    if (response.statusCode != 200) {
      throw Exception('Failed to download update: HTTP ${response.statusCode}');
    }

    int totalBytes = response.contentLength;
    int receivedBytes = 0;

    final digestSink = AccumulatorSink<Digest>();
    final hashSink = sha256.startChunkedConversion(digestSink);

    final sink = file.openWrite();
    await for (var chunk in response) {
      receivedBytes += chunk.length;
      sink.add(chunk);
      hashSink.add(chunk);
      if (totalBytes > 0) {
        onProgress(receivedBytes / totalBytes);
      }
    }
    await sink.flush();
    await sink.close();
    hashSink.close();
    client.close();

    if (info.hasChecksum) {
      final expected = await _fetchExpectedChecksum(info.checksumUrl!);
      final actual = digestSink.events.single.toString();
      if (actual != expected) {
        await file.delete();
        throw Exception(
            'Update failed integrity verification (checksum mismatch). The download was discarded — please try again later or download the installer manually from GitHub.');
      }
      debugPrint('Update checksum verified: $actual');
    } else {
      debugPrint('No checksum published for this release; installing without integrity verification.');
    }

    debugPrint("Download complete. Launching installer...");

    // /SILENT tells Inno Setup to run without user interaction (just a progress bar).
    // The user already confirmed the update in-app before we got here.
    await Process.start(savePath, ['/SILENT']);

    // Exit the Flutter app immediately so the installer can overwrite the files
    exit(0);
  } catch (e) {
    debugPrint('Download/Install error: $e');
    rethrow;
  }
}

/// Minimal accumulator sink so we can hash the download as it streams in
/// (crypto's chunked conversion needs a place to emit the final digest).
class AccumulatorSink<T> implements Sink<T> {
  final List<T> events = [];

  @override
  void add(T event) => events.add(event);

  @override
  void close() {}
}
