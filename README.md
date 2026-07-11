<div align="center">

# 🗣️ Typer - AAC Learning & Communication App

**Typer** is an open-source Augmentative and Alternative Communication (AAC) application built in Flutter. It is specifically designed to help children and non-verbal individuals express themselves, learn new words, and communicate effortlessly using ultra-realistic AI voices.

</div>

---

## ✨ Key Features

* **Ultra-Realistic AI Voices:** Integrates directly with Google Cloud's Neural2 TTS API, offering incredibly human-like voices that dynamically adjust pitch depending on whether the student is a Boy, Girl, Man, or Woman. Works fully offline too, falling back to your device's built-in voices.
* **Smart Phrasebook & Shared Bank:** Save frequently used phrases, and reuse vocabulary lists and phrases across the student profiles on your device through the shared bank.
* **Dynamic Theme Scheduler:** Teachers and parents can assign specific word themes (e.g., "Animals", "Food", "School") to specific days of the week, automatically adapting the student's learning environment.
* **Grown-Ups Only Gate:** Teacher tools (Settings, Word Setup, profile deletion) are protected by a simple math challenge so students can't wander into them by accident.
* **Cross-Platform Auto-Updates:** Available on Windows, Android tablets, and the Web. The Windows desktop version features built-in Over-The-Air (OTA) updates straight from this GitHub repository, verified against a published SHA-256 checksum.
* **Offline-First Profiles:** Create multiple student profiles on a single device. All typing history, usage analytics, and custom words are stored offline. Profiles can be shared via a Profile Code or exported to a backup file, and safely merged between devices.

## 🚀 Getting Started

### Installation
You can download the latest version of Typer from the [Releases page](../../releases).
* **Windows Users:** Download the `Typer_Setup.exe` installer. Future updates will download and install automatically within the app!
* **Android Users:** Download the `app-release.apk` and install it on your tablet. (Updates on Android are installed by downloading the newer APK from the Releases page.)

### Enabling the AI voices (optional)
The app speaks out of the box using your device's built-in voices. To enable the Google Cloud Neural2 voices, paste your own Google Cloud API key in Settings. The key is kept in memory only and forgotten when the app closes. **Safety tip:** in the Google Cloud console, restrict the key so it can only call the Text-to-Speech API.

### Building from Source
If you want to build Typer yourself or contribute to the code:

1. Ensure you have the [Flutter SDK](https://docs.flutter.dev/get-started/install) installed.
2. Clone this repository:
   ```bash
   git clone https://github.com/rein168/forkuya.git
   ```
3. Install dependencies:
   ```bash
   flutter pub get
   ```
4. Run the app:
   ```bash
   flutter run
   ```
5. Run the checks:
   ```bash
   flutter analyze
   flutter test
   ```

## 📦 Releasing a new Windows version

The in-app updater downloads the installer from the latest GitHub release and verifies it against a published checksum. To cut a release:

1. Bump `version:` in `pubspec.yaml` and `MyAppVersion` in `windows_installer.iss`.
2. Build and package:
   ```powershell
   flutter build windows --release
   iscc windows_installer.iss
   ```
3. Generate the checksum file next to the installer (the updater looks for `<installer>.sha256`):
   ```powershell
   $exe = Get-ChildItem build\windows\installer\Typer_Setup*.exe
   (Get-FileHash $exe -Algorithm SHA256).Hash.ToLower() + "  " + $exe.Name | Out-File -Encoding ascii "$($exe.FullName).sha256"
   ```
4. Create a GitHub release tagged `vX.Y.Z` and upload **both** the `.exe` and the `.exe.sha256` file.

If no `.sha256` asset is published, the app still offers the update but warns the user that the download cannot be verified.

## 💖 Supporting the Project
Running ultra-realistic AI voices costs a small fee for every word spoken. If this app has helped you or your child, please consider supporting the project to keep it free for everyone!

[**☕ Support the project on GitHub**](https://github.com/rein168/forkuya)

## 📜 License
This project is open-source and available under the MIT License.
