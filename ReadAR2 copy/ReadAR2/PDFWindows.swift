import SwiftUI
import PDFKit
import UniformTypeIdentifiers
import AVFoundation

struct PageOpenRequest: Codable, Hashable, Transferable {
    static let type = UTType(exportedAs: "com.readar.page-open-request")
    let pageIndex: Int
    static var transferRepresentation: some TransferRepresentation { CodableRepresentation(contentType: type) }
}

#if os(visionOS)
struct PDFBrowserWindow: View {
    @ObservedObject private var pdfManager = PDFManager.shared
    @State private var columns = 4
    @State private var spacing: CGFloat = 16
    @Environment(\.openWindow) private var openWindow
    @State private var pageInput: String = "1"

    var body: some View {
        NavigationStack {
            Group {
                if pdfManager.isLoading {
                    VStack(spacing: 20) {
                        ProgressView().scaleEffect(1.5)
                        Text("Loading PDF...").font(.title2).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let document = pdfManager.pdfDocument {
                    let pageCount = document.pageCount
                    let pageIndex = min(max(pdfManager.selectedPageIndex, 0), max(pageCount - 1, 0))
                    GeometryReader { geo in
                        centeredBrowserContent(document: document, pageIndex: pageIndex, pageCount: pageCount)
                            .frame(width: geo.size.width, height: geo.size.height)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onAppear { pageInput = String(pageIndex + 1) }
                    .onChange(of: pdfManager.selectedPageIndex) { newValue in
                        pageInput = String(min(max(newValue, 0), max(pageCount - 1, 0)) + 1)
                    }
                    .navigationTitle(document.documentURL?.lastPathComponent ?? "PDF Browser")
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "doc.text").font(.system(size: 48)).foregroundColor(.secondary)
                        Text("No PDF loaded").font(.title2).foregroundColor(.secondary)
                        Text("Please upload a PDF from the main window").font(.body).foregroundColor(.secondary).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(minWidth: 500, idealWidth: 600, maxWidth: .infinity, minHeight: 600, idealHeight: 800, maxHeight: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    @ViewBuilder
    private func centeredBrowserContent(document: PDFDocument, pageIndex: Int, pageCount: Int) -> some View {
        ZStack {
            // Centered page view
            ZStack {
                RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial)
                if let page = document.page(at: pageIndex) {
                    PDFPageImageView(page: page)
                        .padding(8)
                } else {
                    Color.clear
                }
            }
            .aspectRatio(8.5/11, contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 80) // leave room for side arrows

            // Left arrow overlay
            HStack {
                Button {
                    let newIndex = max(0, pageIndex - 1)
                    pdfManager.selectPage(newIndex)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 28, weight: .bold))
                }
                .disabled(pageIndex <= 0)
                .padding(.leading, 16)
                Spacer()
            }

            // Right arrow overlay
            HStack {
                Spacer()
                Button {
                    let newIndex = min(pageCount - 1, pageIndex + 1)
                    pdfManager.selectPage(newIndex)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 28, weight: .bold))
                }
                .disabled(pageIndex >= pageCount - 1)
                .padding(.trailing, 16)
            }

            // Bottom center page selector
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Text("Page").font(.footnote).foregroundStyle(.secondary)
                        TextField("\(pageIndex + 1)", text: $pageInput)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            .multilineTextAlignment(.center)
                            .onSubmit {
                                if let n = Int(pageInput), pageCount > 0 {
                                    let idx = min(max(n - 1, 0), pageCount - 1)
                                    pdfManager.selectPage(idx)
                                    pageInput = String(idx + 1)
                                } else {
                                    pageInput = String(pageIndex + 1)
                                }
                            }
                        Text("of \(max(pageCount, 0))").font(.footnote).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(.ultraThinMaterial, in: Capsule())
                    Spacer()
                }
                .padding(.bottom, 16)
            }

            // Bottom-right Open button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        openWindow(value: PageOpenRequest(pageIndex: pageIndex))
                    } label: {
                        Label("Open", systemImage: "arrow.up.right.square")
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.trailing, 16)
                    .padding(.bottom, 16)
                }
            }

            // Top progress overlay
            VStack {
                if pdfManager.isExtractingText {
                    HStack(spacing: 12) {
                        ProgressView(value: pdfManager.extractionProgress)
                            .progressViewStyle(.linear)
                            .frame(maxWidth: 300)
                        Text("Extracting text… \(Int(pdfManager.extractionProgress * 100))%")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 12)
                }
                Spacer()
            }
        }
    }
}

struct PDFPageViewerWindow: View {
    @ObservedObject private var pdfManager = PDFManager.shared
    var initialPageIndex: Int? = nil

    @State private var activeParagraphID: UUID? = nil
    @State private var showMore: Bool = false

    // Gemini summary UI
    @State private var showSummary: Bool = false
    @State private var summaryText: String = ""
    @State private var isSummarizing: Bool = false
    @State private var summaryError: String? = nil

    // TTS state
    @State private var isSpeaking: Bool = false
    @State private var audioPlayer: AVAudioPlayer? = nil
    @State private var audioDelegate = AudioDelegate()
    @State private var playbackRate: Double = 1.0

    // Auto-advance and selection guard
    @State private var autoAdvance: Bool = true
    @State private var suppressSelectionStop: Bool = false

    // Window width control; roulette panel will be 80% of this width
    private let panelWidth: CGFloat = 400

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        GeometryReader { geo in
            content(in: geo.size)
        }
        .onDisappear { stopSpeaking() }
    }

    // MARK: - Content Builder
    @ViewBuilder
    private func content(in size: CGSize) -> some View {
        if let document = pdfManager.pdfDocument {
            let pageIndex = clampedPageIndex(in: document)
            let paragraphs = paragraphsForPage(pageIndex, in: document)
            let items: [ParagraphItem] = paragraphs.enumerated().map { idx, text in
                ParagraphItem(id: stableParagraphID(pageIndex: pageIndex, paragraphIndex: idx, text: text), index: idx, text: text)
            }

            let style = ParagraphRouletteStyle(cardWidth: panelWidth * 0.8 / 1.25)

            ZStack {
                ParagraphRouletteView(
                    paragraphs: items,
                    activeID: $activeParagraphID,
                    style: style
                )
                .id(pageIndex)
            }
            .onAppear {
                if activeParagraphID == nil, let first = items.first?.id {
                    activeParagraphID = first
                }
            }
            .onChange(of: pageIndex) { _ in
                if let first = items.first?.id {
                    activeParagraphID = first
                }
            }
            .onChange(of: activeParagraphID) { _ in
                if suppressSelectionStop {
                    suppressSelectionStop = false
                } else {
                    stopSpeaking()
                }
            }
            .onChange(of: playbackRate) { newRate in
                audioPlayer?.enableRate = true
                audioPlayer?.rate = Float(newRate)
            }
            .frame(
                minWidth: panelWidth,
                idealWidth: panelWidth,
                maxWidth: panelWidth,
                minHeight: 640,
                idealHeight: 844,
                maxHeight: 932,
                alignment: .center
            )
            .frame(width: panelWidth, height: 844, alignment: .center)
            .fixedSize(horizontal: true, vertical: true)
            .position(x: size.width / 2, y: size.height / 2)
            .overlay(alignment: .trailing) {
                EdgeTaskBar(
                    showsLabels: false,
                    alwaysVisible: true,
                    onPrev: {
                        // Move focus to the previous paragraph (up)
                        if let currentID = activeParagraphID,
                           let idx = items.firstIndex(where: { $0.id == currentID }) {
                            let newIndex = max(0, idx - 1)
                            activeParagraphID = items[newIndex].id
                        } else if let first = items.first?.id {
                            activeParagraphID = first
                        }
                    },
                    onRestart: {
                        // Replay the currently selected paragraph from the beginning
                        stopSpeaking()
                        let currentText: String = {
                            if let currentID = activeParagraphID,
                               let idx = items.firstIndex(where: { $0.id == currentID }) {
                                return items[idx].text
                            } else {
                                return items.first?.text ?? ""
                            }
                        }()
                        guard !currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                        startSpeaking(currentText, items: items)
                    },
                    onRewind: {
                        // Rewind 5 seconds; if crossing paragraph boundary, select previous and play
                        if let player = audioPlayer {
                            let newTime = player.currentTime - 5.0
                            if newTime > 0 {
                                player.currentTime = newTime
                                if !player.isPlaying { player.play() }
                                isSpeaking = true
                            } else {
                                // Move to previous paragraph
                                if let currentID = activeParagraphID,
                                   let idx = items.firstIndex(where: { $0.id == currentID }),
                                   idx - 1 >= 0 {
                                    stopSpeaking()
                                    let prev = items[idx - 1]
                                    programmaticSelectionChange { activeParagraphID = prev.id }
                                    let text = prev.text
                                    if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        startSpeaking(text, items: items)
                                    }
                                } else {
                                    // At the first paragraph: restart current from beginning
                                    if let currentID = activeParagraphID,
                                       let idx = items.firstIndex(where: { $0.id == currentID }) {
                                        stopSpeaking()
                                        let text = items[idx].text
                                        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                            startSpeaking(text, items: items)
                                        }
                                    }
                                }
                            }
                        } else {
                            // No player: behave like restart on current paragraph
                            if let currentID = activeParagraphID,
                               let idx = items.firstIndex(where: { $0.id == currentID }) {
                                let text = items[idx].text
                                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    startSpeaking(text, items: items)
                                }
                            }
                        }
                    },
                    onPlayPause: {
                        if isSpeaking {
                            stopSpeaking()
                        } else {
                            let currentText: String = {
                                if let currentID = activeParagraphID,
                                   let idx = items.firstIndex(where: { $0.id == currentID }) {
                                    return items[idx].text
                                } else {
                                    return items.first?.text ?? ""
                                }
                            }()
                            guard !currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                            startSpeaking(currentText, items: items)
                        }
                    },
                    onForward: {
                        // Forward 5 seconds; if crossing paragraph boundary, select next and play
                        if let player = audioPlayer {
                            let newTime = player.currentTime + 5.0
                            if newTime < player.duration {
                                player.currentTime = newTime
                                if !player.isPlaying { player.play() }
                                isSpeaking = true
                            } else {
                                // Move to next paragraph
                                if let currentID = activeParagraphID,
                                   let idx = items.firstIndex(where: { $0.id == currentID }),
                                   idx + 1 < items.count {
                                    stopSpeaking()
                                    let next = items[idx + 1]
                                    programmaticSelectionChange { activeParagraphID = next.id }
                                    let text = next.text
                                    if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        startSpeaking(text, items: items)
                                    }
                                } else {
                                    // At last paragraph: stop
                                    stopSpeaking()
                                }
                            }
                        } else {
                            // No player: jump to next paragraph and play
                            if let currentID = activeParagraphID,
                               let idx = items.firstIndex(where: { $0.id == currentID }),
                               idx + 1 < items.count {
                                let next = items[idx + 1]
                                programmaticSelectionChange { activeParagraphID = next.id }
                                let text = next.text
                                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    startSpeaking(text, items: items)
                                }
                            }
                        }
                    },
                    onNext: {
                        // Move focus to the next paragraph (down)
                        if let currentID = activeParagraphID,
                           let idx = items.firstIndex(where: { $0.id == currentID }) {
                            let newIndex = min(items.count - 1, idx + 1)
                            activeParagraphID = items[newIndex].id
                        } else if let first = items.first?.id {
                            activeParagraphID = first
                        }
                    },
                    onAutoAdvanceToggle: {
                        let currentText: String = {
                            if let currentID = activeParagraphID,
                               let idx = items.firstIndex(where: { $0.id == currentID }) {
                                return items[idx].text
                            } else {
                                return items.first?.text ?? ""
                            }
                        }()
                        let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        openWindow(value: SummaryOpenRequest(paragraph: trimmed))
                    },
                    onOpenMore: { showMore = true }
                )
                .padding(.trailing, 8)
            }
            .popover(isPresented: $showMore) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Reading Options").font(.headline)
                    Toggle("Auto-Advance", isOn: $autoAdvance)
                    HStack {
                        Image(systemName: "tortoise.fill")
                        Slider(value: $playbackRate, in: 0.75...1.5)
                        Image(systemName: "hare.fill")
                    }
                }
                .padding(20)
                .frame(minWidth: 320)
                .glassBackgroundEffect()
            }
        } else {
            emptyState
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No page selected")
                .font(.title2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // Stop TTS playback
    private func stopSpeaking() {
        audioPlayer?.stop()
        audioPlayer = nil
        isSpeaking = false
    }

    private func startSpeaking(_ text: String, items: [ParagraphItem]) {
        Task { @MainActor in
            do {
                let data = try await ElevenLabsTTS.shared.synthesizeAudioData(for: text)
                let player = try ElevenLabsTTS.shared.player(for: data)
                audioPlayer = player
                player.delegate = audioDelegate
                player.enableRate = true
                player.rate = Float(playbackRate)
                audioDelegate.onFinish = {
                    isSpeaking = false
                    if autoAdvance {
                        advanceToNextParagraph(items: items)
                    }
                }
                isSpeaking = true
                player.play()
            } catch {
                isSpeaking = false
                print("[TTS] Failed to speak: \(error)")
            }
        }
    }

    private func advanceToNextParagraph(items: [ParagraphItem]) {
        guard !items.isEmpty else { return }
        if let currentID = activeParagraphID,
           let idx = items.firstIndex(where: { $0.id == currentID }) {
            let nextIndex = idx + 1
            if nextIndex < items.count {
                programmaticSelectionChange {
                    activeParagraphID = items[nextIndex].id
                }
                let nextText = items[nextIndex].text
                if !nextText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    startSpeaking(nextText, items: items)
                }
            }
        } else if let first = items.first {
            programmaticSelectionChange {
                activeParagraphID = first.id
            }
            let firstText = first.text
            if !firstText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                startSpeaking(firstText, items: items)
            }
        }
    }

    private func programmaticSelectionChange(_ updates: () -> Void) {
        suppressSelectionStop = true
        updates()
    }

    // Optional helpers if needed elsewhere
    private func skipBackwardByFiveSeconds(items: [ParagraphItem]) {
        guard let player = audioPlayer else { return }
        let newTime = player.currentTime - 5.0
        if newTime > 0 {
            player.currentTime = newTime
            if !player.isPlaying { player.play() }
            isSpeaking = true
        } else {
            if let currentID = activeParagraphID,
               let idx = items.firstIndex(where: { $0.id == currentID }), idx - 1 >= 0 {
                stopSpeaking()
                let prev = items[idx - 1]
                programmaticSelectionChange { activeParagraphID = prev.id }
                let text = prev.text
                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    startSpeaking(text, items: items)
                }
            }
        }
    }

    private func skipForwardByFiveSeconds(items: [ParagraphItem]) {
        guard let player = audioPlayer else { return }
        let newTime = player.currentTime + 5.0
        if newTime < player.duration {
            player.currentTime = newTime
            if !player.isPlaying { player.play() }
            isSpeaking = true
        } else {
            if let currentID = activeParagraphID,
               let idx = items.firstIndex(where: { $0.id == currentID }), idx + 1 < items.count {
                stopSpeaking()
                let next = items[idx + 1]
                programmaticSelectionChange { activeParagraphID = next.id }
                let text = next.text
                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    startSpeaking(text, items: items)
                }
            } else {
                stopSpeaking()
            }
        }
    }

    // MARK: - Data helpers
    private func clampedPageIndex(in document: PDFDocument) -> Int {
        let preferred = initialPageIndex ?? pdfManager.selectedPageIndex
        return min(max(preferred, 0), max(document.pageCount - 1, 0))
    }

    private func paragraphsForPage(_ index: Int, in document: PDFDocument) -> [String] {
        let resourceName = "page\(index + 1)Demo"
        if let url = urlForDemoPage(named: resourceName),
           let content = try? String(contentsOf: url, encoding: .utf8) {
            return TextSegmentation.paragraphs(from: content)
        }
        // Fallback: extract from the PDF page
        guard let page = document.page(at: index) else { return [] }
        let raw = page.attributedString?.string ?? page.string ?? ""
        return TextSegmentation.paragraphs(from: raw)
    }

    // Stable UUID so selection persists across re-renders
    private func stableParagraphID(pageIndex: Int, paragraphIndex: Int, text: String) -> UUID {
        var hasher = Hasher()
        hasher.combine("page-\(pageIndex)")
        hasher.combine(paragraphIndex)
        hasher.combine(text.prefix(64))
        let h1 = UInt64(bitPattern: Int64(hasher.finalize()))
        var hasher2 = Hasher()
        hasher2.combine("page-\(pageIndex)-para-\(paragraphIndex)")
        hasher2.combine(text.suffix(64))
        let h2 = UInt64(bitPattern: Int64(hasher2.finalize()))
        var bytes = [UInt8](repeating: 0, count: 16)
        withUnsafeBytes(of: h1.bigEndian) { raw in for i in 0..<8 { bytes[i] = raw[i] } }
        withUnsafeBytes(of: h2.bigEndian) { raw in for i in 0..<8 { bytes[8 + i] = raw[i] } }
        // Set version and variant bits
        bytes[6] = (bytes[6] & 0x0F) | 0x40
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    final class AudioDelegate: NSObject, AVAudioPlayerDelegate {
        var onFinish: (() -> Void)?
        func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
            onFinish?()
        }
    }
}
 
// MARK: - Paragraph Bubble
private struct ParagraphBubble: View {
    let index: Int
    let text: String
    let isSelected: Bool
    let width: CGFloat
    let onTap: () -> Void

    var body: some View {
        Text(text)
            .font(.system(size: 20, weight: .regular, design: .default))
            .foregroundStyle(isSelected ? .primary : .secondary)
            .opacity(isSelected ? 1.0 : 0.7)
            .multilineTextAlignment(.leading)
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThinMaterial)
                    .opacity(isSelected ? 1.0 : 0.0)
            )
            .shadow(color: .black.opacity(isSelected ? 0.18 : 0.0), radius: isSelected ? 16 : 0, x: 0, y: isSelected ? 8 : 0)
            .scaleEffect(isSelected ? 1.06 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.9), value: isSelected)
            .contentShape(RoundedRectangle(cornerRadius: 14))
            .onTapGesture(perform: onTap)
            .frame(width: width, alignment: .leading)
    }
}

private extension View {
    func eraseToAnyView() -> AnyView { AnyView(self) }
}

struct PDFPageThumbnailView: View {
    let document: PDFDocument
    let pageIndex: Int
    let onTap: () -> Void
    @State private var isHovered = false
    @State private var thumbnailSize: CGSize = CGSize(width: 150, height: 200)
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(isHovered ? 0.2 : 0.1), radius: isHovered ? 16 : 8, x: 0, y: isHovered ? 6 : 3)
                        .scaleEffect(isHovered ? 1.02 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: isHovered)
                    if let page = document.page(at: pageIndex) {
                        PDFPageImageView(page: page)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .padding(4)
                            .aspectRatio(calculateAspectRatio(for: page), contentMode: .fit)
                    }
                }
                .frame(height: thumbnailSize.height)
                .aspectRatio(8.5/11, contentMode: .fit)
                Text("Page \(pageIndex + 1)").font(.caption.weight(.medium)).foregroundColor(.secondary).padding(.horizontal, 8).padding(.vertical, 4).background(Capsule().fill(.ultraThinMaterial))
            }
        }
        .buttonStyle(.plain)
        .contextMenu { Button("Open in New Window") { onTap() } }
        .onHover { isHovered = $0 }
        .onAppear { if let page = document.page(at: pageIndex) { calculateThumbnailSize(for: page) } }
    }
    private func calculateAspectRatio(for page: PDFPage) -> CGFloat { let r = page.bounds(for: .mediaBox); return r.width / r.height }
    private func calculateThumbnailSize(for page: PDFPage) { let r = page.bounds(for: .mediaBox); let ar = r.width / r.height; let base: CGFloat = 150; thumbnailSize = ar > 1 ? CGSize(width: base, height: base / ar) : CGSize(width: base * ar, height: base / ar) }
}
#endif

#if !os(visionOS)
struct PDFBrowserWindow: View { var body: some View { Text("PDF Browser not available on this platform") } }
struct PDFPageViewerWindow: View { var body: some View { Text("PDF Page Viewer not available on this platform") } }
#endif
//
//  PDFWindows.swift
//  ReadAR
//
//  Created by Eason Ying on 10/4/25.
//


