# 📘 ReadAR — AI-Powered Reading & Comprehension Assistant

ReadAR is a SwiftUI app focused on helping you read smarter by combining PDF reading, visual focus aids, and optional text‑to‑speech. It’s designed to run great on visionOS and also provides fallbacks for other Apple platforms.

---

## 🚀 What’s inside

- 📄 PDF reading powered by PDFKit
- 🧭 Paragraph focus & guided highlighting (per‑line progress with WPM pacing)
- 🗂️ Thumbnail browser and multi‑window navigation on visionOS
- 🔊 Optional Text‑to‑Speech (TTS) playback using ElevenLabs
- 🎛️ Reading controls: next/previous page, paragraph selection, auto‑advance
- 🧪 Demo content support for stable paragraph mapping

> Note: Earlier iterations of this project referenced a lightweight Node.js backend for definitions/summaries. The current codebase you have here focuses primarily on on‑device PDF reading and comprehension features. If you plan to add a backend again, see the Roadmap section.

---

## 📦 Requirements

- Xcode 26.0 or later
- Swift 6.2 toolchain
- Platforms: visionOS, iOS, macOS, tvOS (some features are visionOS‑only)
- PDFKit, AVFoundation (Apple system frameworks)

---

## 🛠️ Setup

1) Clone the repository and open the project in Xcode.

2) Make sure you build with the latest SDKs that ship with Xcode 26.

3) (Optional) Configure ElevenLabs for TTS
   - Add your ElevenLabs API key to your app’s configuration (e.g., in a local secrets file or Info.plist as you prefer). The code expects an `ElevenLabsTTS` helper to provide audio from text. If you don’t configure a key, TTS controls will simply not produce audio.

4) Provide a sample PDF
   - Add a PDF to your app bundle or load one at runtime. Many views in this project expect a `PDFDocument` instance.
   - For the guided paragraph highlighting demo to align paragraphs reliably, include optional text files named like `page1Demo`, `page2Demo`, etc., in your bundle. These help the reader map visually segmented paragraphs to the PDF text more robustly.

---

## ▶️ Running the app

- visionOS
  - Use the `PDFBrowserWindow` to browse pages and open a focused `PDFPageViewerWindow` with paragraph navigation, playback controls, and optional TTS.
  - The UI includes:
    - Page thumbnails and page navigation
    - Paragraph selection and auto‑advance
    - Playback controls (play/pause, rewind/forward, previous/next paragraph)

- iOS/macOS
  - Fallback views are provided where visionOS‑specific windows aren’t available. PDF rendering and basic navigation still work via the `PDFViewWrapper`.

---

## 🧩 How it works

- PDF rendering
  - `PDFKitWrappers.swift` exposes `PDFPageImageView` and platform wrappers for `PDFView` to integrate with SwiftUI.

- visionOS windows & navigation
  - `PDFWindows.swift` defines `PDFBrowserWindow` and `PDFPageViewerWindow` with a focus on multi‑window navigation, page selection, and paragraph‑level controls.

- Paragraph extraction & highlighting
  - `PDFReaderView.swift` contains:
    - `ParagraphExtractor` — maps demo paragraph text to locations in the PDF using flexible matching
    - `PDFReaderView` — draws overlay tracks and animates a per‑line highlight based on WPM pacing
    - A ticking loop advances the highlight across lines and paragraphs

- Thumbnails (visionOS)
  - `PDFThumbnailBrowserView.swift` wraps `PDFThumbnailView` and wires selection callbacks.

- Text‑to‑Speech (optional)
  - Several views reference an `ElevenLabsTTS` helper (not shown here) to synthesize audio. If present and configured, the app will play paragraph audio and auto‑advance.

---

## 🔧 Configuration details

- Demo paragraph mapping
  - Place text resources named `page<N>Demo` (e.g., `page1Demo`) in your bundle to stabilize paragraph mapping. Each file should contain the plain text of that PDF page split into paragraphs (separated by blank lines). The extractor uses a relaxed whitespace‑tolerant match to locate each paragraph in the PDF’s extracted text.

- WPM pacing
  - The highlight driver estimates per‑line durations based on WPM and word counts, with clamping and punctuation‑aware adjustments.

- Accessibility
  - Interactive overlays expose accessibility labels with paragraph text. Controls include clear labels for playback actions.

---

## 🧱 Project structure (selected files)

