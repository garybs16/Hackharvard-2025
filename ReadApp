// ReadAR – AI-Powered Spatial Reading Assistant (visionOS MVP)
// HackHarvard 2025
// ---------------------------------------------------------
// This is a minimal, demo-ready visionOS SwiftUI project skeleton
// focusing on: line highlight, syllable mode, TTS, word-tap lookup (stub),
// gaze-driven focus via SwiftUI's focus system, and simple file import.
// PDF parsing is stubbed behind feature flags; for the hackathon, stick to .txt
// or paste text.
// ---------------------------------------------------------
// Project structure (single-file demo; split into files in Xcode):
// - ReadARApp: App entry
// - Models: ReaderSettings, ReaderState, syllable/linguistics helpers
// - Services: SpeechService, DefinitionService (stub), PDFService (stub)
// - Views: ContentView, ReaderView, LineRow, Toolbar
// ---------------------------------------------------------

import SwiftUI
import AVFoundation
import NaturalLanguage
import UniformTypeIdentifiers

// MARK: - Models

enum FocusMode: String, CaseIterable, Identifiable {
    case lineFocus = "Line Focus"
    case syllable = "Syllable Mode"
    case plain = "Plain"
    var id: String { rawValue }
}

struct ReaderSettings {
    var focusMode: FocusMode = .lineFocus
    var fontSize: CGFloat = 20
    var lineSpacing: CGFloat = 8
    var backgroundColor: Color = Color(white: 0.06)
    var foregroundColor: Color = .white
    var highlightColor: Color = Color.yellow.opacity(0.25)
    var showTimestamps: Bool = false
}

final class ReaderState: ObservableObject {
    @Published var text: String = SampleText.lorem
    @Published var lines: [String] = []
    @Published var focusedLineIndex: Int? = nil
    @Published var selectedWord: String? = nil
    @Published var settings = ReaderSettings()
    @Published var isSpeaking: Bool = false
    @Published var showDefinitionSheet: Bool = false
    @Published var importError: String? = nil

    init() {
        recalcLines()
    }

    func recalcLines() {
        // Simple line split – in a real app, shape by layout width using TextLayout
        lines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")
            .flatMap { $0.isEmpty ? [""] : [$0] }
    }
}

// MARK: - Services

final class SpeechService: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    @Published var isSpeaking: Bool = false

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String, lang: String? = nil) {
        stop()
        let utterance = AVSpeechUtterance(string: text)
        if let lang = lang, AVSpeechSynthesisVoice.speechVoices().contains(where: { $0.language == lang }) {
            utterance.voice = AVSpeechSynthesisVoice(language: lang)
        }
        utterance.rate = 0.44
        utterance.pitchMultiplier = 1.0
        synthesizer.speak(utterance)
        isSpeaking = true
    }

    func stop() {
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        isSpeaking = false
    }

    // MARK: AVSpeechSynthesizerDelegate
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.isSpeaking = false }
    }
}

struct DefinitionResult { let word: String; let definition: String }

final class DefinitionService {
    // Stub: returns a simple heuristic definition; replace with OpenAI/Dictionary API in prod
    func define(_ word: String, locale: Locale = .current) async -> DefinitionResult {
        let lower = word.lowercased()
        let def: String
        switch lower {
        case "adhd": def = "Attention-Deficit/Hyperactivity Disorder; affects attention and impulse control.";
        case "dyslexia": def = "A learning difference affecting reading and spelling.";
        default:
            def = "No dictionary connected in MVP. Meaning of ‘\(word)’ depends on context."
        }
        return DefinitionResult(word: word, definition: def)
    }
}

// Optional stub for PDF parsing in future; on visionOS, prefer text import for MVP
enum PDFService {
    static func extractText(from url: URL) throws -> String {
        // TODO: integrate PDFKit if available on target; fallback to CoreGraphics text extraction
        // For MVP, we decline and advise using .txt
        throw NSError(domain: "ReadAR", code: 1, userInfo: [NSLocalizedDescriptionKey: "PDF import not enabled in MVP. Please use .txt."])
    }
}

// MARK: - Linguistics Utilities

enum Linguistics {
    static func syllabify(_ word: String) -> [String] {
        // Heuristic syllable split using hyphenation; not perfect but demo-friendly
        let ns = word as NSString
        var pieces: [String] = []
        var index = ns.length
        let locale = CFLocaleCopyCurrent()
        while index > 0 {
            let breakIndex = CFStringGetHyphenationLocationBeforeIndex(ns, index, CFRange(location: 0, length: ns.length), 0, locale, nil)
            if breakIndex == kCFNotFound { break }
            let part = ns.substring(with: NSRange(location: breakIndex, length: index - breakIndex))
            pieces.insert(part, at: 0)
            index = breakIndex
        }
        if index > 0 { pieces.insert(ns.substring(to: index), at: 0) }
        return pieces.isEmpty ? [word] : pieces
    }
}

// MARK: - Views

@main
struct ReadARApp: App {
    @StateObject private var state = ReaderState()
    @StateObject private var speech = SpeechService()
    private let defService = DefinitionService()

    var body: some Scene {
        WindowGroup("ReadAR") {
            ContentView()
                .environmentObject(state)
                .environmentObject(speech)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.volumetric)
    }
}

struct ContentView: View {
    @EnvironmentObject var state: ReaderState
    @EnvironmentObject var speech: SpeechService
    @State private var isImporterPresented = false
    @State private var importerTypes: [UTType] = [.plainText] // Add .pdf later if supported

    var body: some View {
        VStack(spacing: 0) {
            ToolbarView(onImport: { isImporterPresented = true }, onSpeakToggle: speakToggle, onClear: clearText)
            Divider().opacity(0.3)
            ReaderView()
        }
        .background(state.settings.backgroundColor.ignoresSafeArea())
        .fileImporter(isPresented: $isImporterPresented, allowedContentTypes: importerTypes) { result in
            switch result {
            case .success(let url):
                do {
                    if url.startAccessingSecurityScopedResource() { defer { url.stopAccessingSecurityScopedResource() } }
                    if url.conforms(to: .plainText) {
                        let txt = try String(contentsOf: url, encoding: .utf8)
                        state.text = txt; state.recalcLines()
                    } else if url.conforms(to: .pdf) {
                        // Disabled for MVP – show message
                        throw NSError(domain: "ReadAR", code: 2, userInfo: [NSLocalizedDescriptionKey: "PDF import disabled in MVP. Use a .txt file."])
                    }
                } catch {
                    state.importError = error.localizedDescription
                }
            case .failure(let error):
                state.importError = error.localizedDescription
            }
        }
        .alert("Import Error", isPresented: Binding(get: { state.importError != nil }, set: { _ in state.importError = nil })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(state.importError ?? "")
        }
    }

    private func speakToggle() {
        if speech.isSpeaking { speech.stop() } else {
            let line = currentLineText()
            speech.speak(line.isEmpty ? state.text : line)
        }
    }

    private func clearText() { state.text = ""; state.recalcLines() }

    private func currentLineText() -> String {
        guard let idx = state.focusedLineIndex, idx < state.lines.count else { return "" }
        return state.lines[idx]
    }
}

struct ToolbarView: View {
    @EnvironmentObject var state: ReaderState
    @EnvironmentObject var speech: SpeechService

    var onImport: () -> Void
    var onSpeakToggle: () -> Void
    var onClear: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Text("ReadAR")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.white)
            Spacer()
            Picker("Mode", selection: $state.settings.focusMode) {
                ForEach(FocusMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 420)

            HStack(spacing: 8) {
                Label("Font", systemImage: "textformat.size")
                Slider(value: $state.settings.fontSize, in: 14...40)
                    .frame(width: 180)
            }

            HStack(spacing: 8) {
                Label("Spacing", systemImage: "line.3.horizontal")
                Slider(value: $state.settings.lineSpacing, in: 4...24)
                    .frame(width: 180)
            }

            Button(action: onSpeakToggle) {
                Label(speech.isSpeaking ? "Stop" : "Read Aloud", systemImage: speech.isSpeaking ? "stop.circle" : "play.circle")
            }

            Button(action: onImport) { Label("Import", systemImage: "tray.and.arrow.down") }
            Button(role: .destructive, action: onClear) { Label("Clear", systemImage: "trash") }
        }
        .padding(16)
        .background(.ultraThinMaterial)
    }
}

struct ReaderView: View {
    @EnvironmentObject var state: ReaderState
    @EnvironmentObject var speech: SpeechService
    @FocusState private var focusIndex: Int?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: state.settings.lineSpacing) {
                ForEach(state.lines.indices, id: \.self) { idx in
                    LineRow(index: idx, text: state.lines[idx], highlighted: focusIndex == idx)
                        .focusable(true) // visionOS focus engine reacts to eye gaze + pointer/tap
                        .focused($focusIndex, equals: idx)
                        .onFocusChange { isFocused in
                            if isFocused { state.focusedLineIndex = idx }
                        }
                }
            }
            .padding(24)
        }
        .onChange(of: state.settings.focusMode) { _ in
            // When mode changes, keep current focus consistent
            if let idx = state.focusedLineIndex { focusIndex = idx }
        }
        .onAppear {
            if focusIndex == nil { focusIndex = 0; state.focusedLineIndex = 0 }
        }
    }
}

struct LineRow: View {
    @EnvironmentObject var state: ReaderState
    @State private var showPopover = false

    let index: Int
    let text: String
    let highlighted: Bool

    var body: some View {
        let bg = highlighted && state.settings.focusMode != .plain ? state.settings.highlightColor : .clear

        VStack(alignment: .leading, spacing: 6) {
            switch state.settings.focusMode {
            case .syllable:
                SyllableLine(text: text)
            default:
                WordLine(text: text)
            }
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(bg)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct WordLine: View {
    @EnvironmentObject var state: ReaderState
    @State private var definition: DefinitionResult? = nil
    @State private var showDefinition = false
    private let defService = DefinitionService()

    let text: String

    var body: some View {
        let words = tokenize(text)
        return Text(AttributedString()) // placeholder to enable Group below
            .overlay(alignment: .leading) {
                WrapHStack(spacing: 8, verticalSpacing: 6) {
                    ForEach(words, id: \.self) { w in
                        Button(action: { Task { await defineWord(w) } }) {
                            Text(w)
                                .font(.system(size: state.settings.fontSize))
                                .foregroundColor(state.settings.foregroundColor)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Define ‘\(w)’") { Task { await defineWord(w) } }
                            Button("Speak ‘\(w)’") { AVSpeechSynthesizer().speak(AVSpeechUtterance(string: w)) }
                        }
                    }
                }
            }
            .sheet(isPresented: $showDefinition) {
                if let def = definition {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(def.word).font(.title.bold())
                        Text(def.definition).font(.title3)
                        Button("Close") { showDefinition = false }
                    }
                    .padding(24)
                    .presentationDetents([.medium])
                }
            }
    }

    private func tokenize(_ s: String) -> [String] {
        s.split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "'" })
            .map(String.init)
    }

    private func defineWord(_ w: String) async {
        definition = await defService.define(w)
        showDefinition = true
    }
}

struct SyllableLine: View {
    @EnvironmentObject var state: ReaderState
    let text: String

    var body: some View {
        let words = text.split(separator: " ").map(String.init)
        WrapHStack(spacing: 8, verticalSpacing: 6) {
            ForEach(words, id: \.self) { word in
                let syllables = Linguistics.syllabify(word)
                HStack(spacing: 0) {
                    ForEach(Array(syllables.enumerated()), id: \.offset) { i, syl in
                        Text(syl)
                            .font(.system(size: state.settings.fontSize))
                            .foregroundColor(state.settings.foregroundColor)
                        if i < syllables.count - 1 {
                            Text("·")
                                .font(.system(size: state.settings.fontSize * 0.9))
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Layout helper: wrap HStack

struct WrapHStack<Content: View>: View {
    var spacing: CGFloat
    var verticalSpacing: CGFloat
    @ViewBuilder var content: Content

    init(spacing: CGFloat = 8, verticalSpacing: CGFloat = 8, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.verticalSpacing = verticalSpacing
        self.content = content()
    }

    var body: some View {
        FlowLayout(spacing: spacing, verticalSpacing: verticalSpacing) { content }
    }
}

struct FlowLayout<Content: View>: View {
    let spacing: CGFloat
    let verticalSpacing: CGFloat
    @ViewBuilder let content: Content

    init(spacing: CGFloat, verticalSpacing: CGFloat, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.verticalSpacing = verticalSpacing
        self.content = content()
    }

    var body: some View {
        GeometryReader { proxy in
            self.generateContent(in: proxy.size.width)
        }
        .frame(maxWidth: .infinity)
    }

    private func generateContent(in totalWidth: CGFloat) -> some View {
        var width: CGFloat = 0
        var rows: [[AnyView]] = [[]]

        let views = contentToArray()
        for view in views {
            let viewSize = view.intrinsicSize()
            if width + viewSize.width + spacing > totalWidth {
                rows.append([view])
                width = viewSize.width + spacing
            } else {
                rows[rows.count - 1].append(view)
                width += viewSize.width + spacing
            }
        }

        return VStack(alignment: .leading, spacing: verticalSpacing) {
            ForEach(0..<rows.count, id: \.self) { row in
                HStack(spacing: spacing) {
                    ForEach(0..<rows[row].count, id: \.self) { col in
                        rows[row][col]
                    }
                }
            }
        }
    }

    private func contentToArray() -> [AnyView] {
        let mirror = Mirror(reflecting: content)
        var arr: [AnyView] = []
        for child in mirror.children {
            if let v = child.value as? AnyView {
                arr.append(v)
            } else if let v = child.value as? _VariadicView.Children {
                for c in Mirror(reflecting: v).children {
                    if let any = c.value as? AnyView { arr.append(any) }
                }
            }
        }
        return arr
    }
}

extension View {
    func intrinsicSize() -> CGSize {
        let controller = UIHostingController(rootView: self)
        let size = controller.sizeThatFits(in: UIView.layoutFittingExpandedSize)
        return size == .zero ? CGSize(width: 40, height: 24) : size
    }
}

// MARK: - Sample Text

enum SampleText {
    static let lorem = """
ReadAR – Helping every mind read clearly.
Tap any word to define it. Toggle Syllable Mode to see separators. Use Read Aloud for TTS.

1) This MVP highlights the line you look at (via the focus system) and supports adjustable font sizes.
2) Syllable Mode uses hyphenation heuristics (demo-quality).
3) Import a .txt file to try longer passages.
"""
}
