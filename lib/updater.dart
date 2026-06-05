import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

const String githubRepo = 'rein168/forkuya';

/// Checks GitHub for a new release. Returns the download URL of the .exe if an update is available.
Future<String?> checkForUpdates() async {
  try {
    final response = await http.get(Uri.parse('https://api.github.com/repos/$githubRepo/releases/latest'));
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final latestTag = data['tag_name'] as String; // e.g. 'v1.0.1'
      
      final packageInfo = await PackageInfo.fromPlatform();
      // Format our local version to match GitHub tags: 'v1.0.0'
      final currentVersion = 'v${packageInfo.version}';
      
      print("Current Version: $currentVersion | Latest on GitHub: $latestTag");

      // For testing purposes, if you want to force an update check, 
      // you could change this to: if (true) {
      if (latestTag != currentVersion) {
        final assets = data['assets'] as List;
        for (var asset in assets) {
          if (asset['name'].toString().toLowerCase().endsWith('.exe')) {
            return asset['browser_download_url'];
          }
        }
      }
    }
  } catch (e) {
    print('Error checking for updates: $e');
  }
  return null;
}

/// Downloads the .exe to the Windows Temp folder and executes it.
Future<void> downloadAndInstallUpdate(String downloadUrl, Function(double) onProgress) async {
  try {
    final tempDir = Directory.systemTemp;
    final savePath = '${tempDir.path}\\Typer_Setup_Update.exe';
    final file = File(savePath);
    
    final client = HttpClient();
    final request = await client.getUrl(Uri.parse(downloadUrl));
    final response = await request.close();
    
    if (response.statusCode != 200) {
      throw Exception('Failed to download update: HTTP ${response.statusCode}');
    }

    int totalBytes = response.contentLength;
    int receivedBytes = 0;
    
    final sink = file.openWrite();
    await for (var chunk in response) {
      receivedBytes += chunk.length;
      sink.add(chunk);
      if (totalBytes > 0) {
         onProgress(receivedBytes / totalBytes);
      }
    }
    await sink.flush();
    await sink.close();
    
    print("Download complete. Launching installer...");
    
    // Launch the downloaded installer in the background
    // /SILENT tells Inno Setup to run without user interaction (just a progress bar)
    await Process.start(savePath, ['/SILENT']);
    
    // Exit the Flutter app immediately so the installer can overwrite the files
    exit(0);
  } catch (e) {
    print('Download/Install error: $e');
    throw Exception('Failed to download or install the update.');
  }
}
