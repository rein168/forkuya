<div align="center">

# ⌨️ Typer - AAC Learning & Communication App

**Typer** is an open-source Augmentative and Alternative Communication (AAC) progressive web app built with Flutter. It is specifically designed to empower non-verbal individuals, early readers, and children learning to communicate and type, featuring offline neural AI voices, visual prompt fading, and accessible pedagogical tools.

[![Flutter](https://img.shields.io/badge/Flutter-Web-blue?logo=flutter)](https://flutter.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![PWA](https://img.shields.io/badge/PWA-Ready-green?logo=pwa)](https://rein168.github.io/forkuya/)

</div>

---

## ✨ Key Features

### 🖼️ Visual Prompt Fading & AAC Symbols
* **ARASAAC Pictograms:** Automatically fetches and caches standardized, high-quality AAC pictograms from the ARASAAC symbol library for practice words.
* **Custom Photo Uploads:** Teachers and parents can upload real photographs (family, pets, classroom objects) directly from their device camera or photo roll to replace cartoons with familiar real-world cues.
* **Pedagogical Prompt Fading:** Toggle the text visibility (eye icon) while leaving the visual symbol on screen. This allows learners to transition from reading text to recognizing symbols, or vice-versa, fading out scaffolding as reading independence grows.
* **Guaranteed Offline Starter Pack:** Ships with 6 core themes (**Core Words**, **Food & Drink**, **Animals**, **Colors**, **Toys & Play**, and **Body Parts**) totaling 56 pre-bundled offline symbols—ready to use out-of-the-box in airplane mode.

### 🔤 Early-Reader Lowercase Typography
* **Natural Reading Presentation:** All student-facing practice words, typed letters, on-screen keyboard keys (`a`–`z`, `space`, `del`, `enter`), and hint instructions display in lowercase. Designed in consultation with speech therapy to match real-world books and environmental print.
* **Robust Internal Architecture:** Keeps storage and keyboard routing case-insensitive in uppercase under the hood, ensuring 100% backwards compatibility and zero data migration breaks.

### 🎙️ Ultra-Realistic Offline Neural AI Voices
* **Dual Offline TTS Engines:** Features high-quality offline neural voices powered by **Kokoro-82M** (via ONNX WebGPU/WASM) and bundled **Piper TTS** models (Boy, Girl, Man, Woman).
* **100% Private & Free:** Audio synthesis runs completely within the browser. Zero cloud API calls, zero usage fees, and zero latency once models are cached.

### ♿ Accessibility & Child-Centered Controls
* **Icon-Only SPEAK Button:** An optional per-profile toggle in Settings that transforms the text-labeled button into a clean speaker icon. Prevents children from accidentally typing out "S-P-E-A-K" into the text line.
* **Screen Reader Semantics:** Includes explicit ARIA/Semantics announcements for TalkBack and VoiceOver across all interactive controls.
* **Accessibility Fonts:** Instant font switching between specialized reading typefaces: **Lexend**, **OpenDyslexic**, **Atkinson Hyperlegible**, and **Comic Neue**.
* **Adaptive Keyboard:** Automatically detects physical hardware keyboards and can auto-hide the on-screen keyboard to maximize canvas space.

### 🏫 Teacher & Parent Toolkit
* **Dynamic Theme Scheduler:** Plan vocabulary ahead of time by scheduling specific themes to days of the week.
* **Grown-Ups Only Gate:** Settings, profile editing, and theme management are guarded by a parent/teacher arithmetic math challenge to prevent accidental modifications.
* **Multi-Profile CRDT Storage:** Maintain multiple independent student profiles on a single device. All profiles utilize Conflict-Free Replicated Data Types (LWW-Set) for safe importing, exporting, and merging across devices without data loss.

---

## 🚀 Installation & Usage

Typer is built as an offline-first **Progressive Web App (PWA)**—no app store or installer required!

1. Open **[https://rein168.github.io/forkuya/](https://rein168.github.io/forkuya/)** in any modern web browser (Chrome, Edge, Safari).
2. Tap the browser menu and select **"Add to Home Screen"** or **"Install App"**.
3. Launch Typer from your home screen or desktop. It will run in standalone mode with full offline support and automatic background updates.

---

## 🛠️ Tech Stack

* **Framework:** [Flutter](https://flutter.dev/) (Web)
* **Speech Synthesis:** Kokoro-82M ONNX (`onnxruntime-web`), Piper TTS (Web Worker + WASM)
* **Data Model:** Conflict-Free Replicated Data Types (LWW-Set CRDT) with local persistent storage
* **Symbol Set:** [ARASAAC](https://arasaac.org/) Pictographic symbols
* **Deployment:** GitHub Pages via GitHub Actions CI/CD

---

## 📄 License & Attribution

* **Software:** Licensed under the [MIT License](LICENSE).
* **Pictograms:** ARASAAC symbols are produced by the Government of Aragon and distributed under the [Creative Commons License BY-NC-SA](https://creativecommons.org/licenses/by-nc-sa/4.0/).
