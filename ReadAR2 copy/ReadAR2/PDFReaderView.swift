import SwiftUI
import PDFKit
import UIKit
import AVFoundation

#if os(visionOS)

// MARK: - Data Models
struct ParagraphRegion: Identifiable, Hashable {
    let id = UUID()
    let pageIndex: Int
    let nsRange: NSRange
    let text: String
    let rectsInPageSpace: [CGRect]
}

// MARK: - Paragraph Extraction Helper (geometry-aware)
final class ParagraphExtractor {
    private func normalize(_ s: String) -> String {
        var t = s.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        t = t.replacingOccurrences(of: "\u{00A0}", with: " ") // NBSP
        // Straighten quotes
        t = t.replacingOccurrences(of: "“", with: "\"").replacingOccurrences(of: "”", with: "\"")
        t = t.replacingOccurrences(of: "‘", with: "'").replacingOccurrences(of: "’", with: "'")
        // Collapse whitespace
        t = t.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func regexEscaped(_ s: String) -> String {
        NSRegularExpression.escapedPattern(for: s)
    }

    // Tries to find `needle` in `haystack` allowing flexible whitespace.
    private func looseRange(of needle: String, in haystack: String, startAt: Int) -> NSRange {
        let words = needle.split{ $0.isWhitespace || $0.isNewline }
        guard !words.isEmpty else { return NSRange(location: NSNotFound, length: 0) }
        let pattern = words.map { regexEscaped(String($0)) }.joined(separator: "\\s+")
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let ns = haystack as NSString
        let search = NSRange(location: startAt, length: max(0, ns.length - startAt))
        return regex?.firstMatch(in: haystack, options: [], range: search)?.range ?? NSRange(location: NSNotFound, length: 0)
    }

    // Text-driven extraction that maps demo paragraphs to PDF ranges and collects line rects
    func extractParagraphs(from document: PDFDocument) -> [ParagraphRegion] {
        var results: [ParagraphRegion] = []
        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            // Load demo content for this page
            let resourceName = "page\(pageIndex + 1)Demo"
            guard let url = urlForDemoPage(named: resourceName),
                  let content = try? String(contentsOf: url, encoding: .utf8) else { continue }
            let paragraphs = TextSegmentation.paragraphs(from: content)

            // Search each paragraph sequentially in the page's extracted text to get a stable NSRange
            let haystack = (page.attributedString?.string ?? page.string ?? "") as NSString
            var cursor = 0
            for para in paragraphs {
                // Try strict search first
                var searchRange = NSRange(location: cursor, length: max(0, haystack.length - cursor))
                var found = haystack.range(of: para, options: [], range: searchRange)
                if found.location == NSNotFound {
                    // Flexible whitespace regex over the ORIGINAL haystack to avoid index drift
                    let originalHay = haystack as String
                    // Normalize only quotes/NBSP in the needle, leave whitespace flexible
                    let normPara = normalize(para)
                    let words = normPara.split { $0.isWhitespace || $0.isNewline }.map(String.init)
                    if !words.isEmpty {
                        let pattern = words.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "\\s+")
                        if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
                            let search = NSRange(location: 0, length: (originalHay as NSString).length)
                            if let match = regex.firstMatch(in: originalHay, options: [], range: search) {
                                found = match.range
                                print("[Reader] regex-mapped paragraph len=\(para.count) -> range=\(found)")
                            }
                        }
                    }
                }
                let nsRange = (found.location != NSNotFound) ? found : NSRange(location: 0, length: 0)
                if nsRange.location != NSNotFound {
                    cursor = nsRange.location + nsRange.length
                    print("[Reader] Page \(pageIndex) mapped paragraph (len=\(para.count)) -> range=\(nsRange)")
                } else {
                    print("[Reader][WARN] Page \(pageIndex) failed to map paragraph (len=\(para.count))")
                }

                // Collect rects per line in page space
                var pageRects: [CGRect] = []
                if nsRange.length > 0, let sel = page.selection(for: nsRange) {
                    let lines = sel.selectionsByLine()
                    for line in lines {
                        let r = line.bounds(for: page)
                        if !r.isNull && !r.isEmpty { pageRects.append(r) }
                    }
                }
                print("[Reader] Page \(pageIndex) paragraph rects=\(pageRects.count)")

                results.append(ParagraphRegion(pageIndex: pageIndex,
                                               nsRange: nsRange,
                                               text: para,
                                               rectsInPageSpace: pageRects))
            }
        }
        return results
    }
}

// MARK: - UIViewRepresentable container for PDFView
struct PDFViewContainer: UIViewRepresentable {
    @Binding var pdfViewRef: PDFView?
    let document: PDFDocument

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .clear

        // Expose reference after layout
        DispatchQueue.main.async { self.pdfViewRef = pdfView }

        // Observe page changes (hook available)
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged(_:)),
            name: Notification.Name.PDFViewPageChanged,
            object: pdfView
        )
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document !== document { uiView.document = document }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject {
        @objc func pageChanged(_ notification: Notification) {
            // Reserved: could publish page index changes
        }
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }
}

// MARK: - Main Reader View with overlay and controls
struct PDFReaderView: View {
    @Binding var pdfViewRef: PDFView?
    let document: PDFDocument

    @State private var regions: [ParagraphRegion] = []
    @State private var focusedParagraphID: ParagraphRegion.ID?
    @State private var focusScale: CGFloat = 1.0

    // Highlight driver state
    @State private var wpm: Double = 120
    @State private var isRunning: Bool = false
    @State private var currentLineIndex: Int = 0
    @State private var lineProgress: CGFloat = 0
    @State private var lineDurations: [TimeInterval] = []
    @State private var lastTick: Date = .init()
    @State private var showWPMSheet: Bool = false

    // Debug
    @State private var debugLogs: Bool = true
    @State private var debugTickCounter: Int = 0

    // Added for speech
    @State private var isSpeaking = false
    @State private var audioPlayer: AVAudioPlayer?
    @State private var speakTask: Task<Void, Never>?
    private let tts = ElevenLabsTTS.shared
    private func textForSpeech() -> String {
        if let url = urlForDemoPage(named: "page1Demo"),
           let data = try? Data(contentsOf: url),
           let text = String(data: data, encoding: .utf8) { return text }
        return "No document text was found. This is a demo narration using ElevenLabs."
    }
    private func stopSpeaking() {
        audioPlayer?.stop()
        audioPlayer = nil
        isSpeaking = false
        speakTask?.cancel()
        speakTask = nil
    }

    private let extractor = ParagraphExtractor()

    var body: some View {
        ZStack {
            PDFViewContainer(pdfViewRef: $pdfViewRef, document: document)
                .overlay(overlayLayer)
                .overlay(dimLayer)

            // Paging controls
            VStack {
                Spacer()
                HStack(spacing: 20) {
                    Button(action: goToPreviousPage) { Label("Previous", systemImage: "chevron.left") }
                        .buttonStyle(.borderedProminent)
                    Button(action: goToNextPage) { Label("Next", systemImage: "chevron.right") }
                        .buttonStyle(.borderedProminent)
                }
                .padding(12)
                .background(.ultraThinMaterial, in: Capsule())
                .padding()
            }

            // Highlight driver ticker
            TimelineView(.animation) { context in
                Color.clear
                    .onChange(of: context.date) { _ in
                        guard isRunning, currentLineIndex < lineDurations.count else { return }
                        let now = context.date
                        let dt = now.timeIntervalSince(lastTick)
                        lastTick = now
                        let dur = lineDurations[currentLineIndex]
                        if dur > 0 {
                            lineProgress = min(1.0, lineProgress + CGFloat(dt / dur))
                            debugTickCounter += 1
                            if debugTickCounter % 30 == 0 { // throttle logs
                                print("[Reader] tick line=\(currentLineIndex) progress=\(String(format: "%.2f", lineProgress))")
                            }
                            if lineProgress >= 1.0 {
                                print("[Reader] line complete idx=\(currentLineIndex)")
                                // small dwell
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                    advanceToNextLineOrParagraph()
                                }
                            }
                        }
                    }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Button(action: {
                if isSpeaking {
                    stopSpeaking()
                } else {
                    let text = textForSpeech()
                    speakTask = Task { @MainActor in
                        do {
                            let player = try await tts.speak(text: text)
                            audioPlayer = player
                            isSpeaking = true
                        } catch {
                            isSpeaking = false
                        }
                    }
                }
            }) {
                Image(systemName: isSpeaking ? "stop.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(18)
                    .background(
                        Circle()
                            .fill(Color.blue)
                            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                    )
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.25), lineWidth: 1)
                    )
                    .accessibilityLabel(isSpeaking ? "Stop narration" : "Play narration")
            }
            .padding(.trailing, 20)
            .padding(.bottom, 20)
        }
        .onAppear(perform: computeParagraphsIfNeeded)
        .onChange(of: focusedParagraphID) { newValue in
            print("[Reader] focus changed -> \(String(describing: newValue))")
            if let id = newValue, let region = regions.first(where: { $0.id == id }) {
                startHighlight(for: region)
                withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) { focusScale = 1.04 }
            } else {
                stopHighlight()
                withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) { focusScale = 1.0 }
            }
        }
    }

    // MARK: Overlay Layer
    private var overlayLayer: some View {
        GeometryReader { _ in
            ZStack {
                ForEach(regions) { region in
                    if let overlayRects = overlayRectsFor(region: region) {
                        // Draw tracks for all lines
                        ForEach(overlayRects.indices, id: \.self) { idx in
                            let rect = overlayRects[idx]
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.yellow.opacity(0.08))
                                .frame(width: rect.width, height: max(6, min(12, rect.height * 0.25)))
                                .position(x: rect.midX, y: rect.maxY + 8)
                                .allowsHitTesting(false)
                        }
                        // Active line fill
                        if focusedParagraphID == region.id,
                           currentLineIndex < overlayRects.count {
                            let rect = overlayRects[currentLineIndex]
                            let fillWidth = rect.width * max(0, min(1, lineProgress))
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.yellow.opacity(0.5))
                                .frame(width: fillWidth, height: max(6, min(12, rect.height * 0.25)))
                                .position(x: rect.minX + fillWidth / 2, y: rect.maxY + 8)
                                .shadow(color: .yellow.opacity(0.6), radius: 6, x: 0, y: 0)
                                .allowsHitTesting(false)
                        }
                        ForEach(overlayRects.indices, id: \.self) { idx in
                            let rect = overlayRects[idx]
                            // Expand hit area slightly for easier tapping
                            let hitInset: CGFloat = -8
                            Rectangle()
                                .fill(Color.clear)
                                .frame(width: rect.width - hitInset * 2, height: rect.height - hitInset * 2)
                                .position(x: rect.midX, y: rect.midY)
                                .contentShape(Rectangle())
                                .overlay(
                                    // Debug outline to visualize hit area (toggle by commenting)
                                    RoundedRectangle(cornerRadius: 2)
                                        .stroke(Color.yellow.opacity(0.15), lineWidth: 1)
                                        .frame(width: rect.width - hitInset * 2, height: rect.height - hitInset * 2)
                                )
                                .zIndex(10) // ensure above tracks
                                #if os(visionOS)
                                .onTapGesture {
                                    print("[Reader] tap on rect idx=\(idx) region=\(region.id) size=\(String(format: "%.1f×%.1f", rect.width, rect.height))")
                                    focusedParagraphID = region.id
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) { focusScale = 1.04 }
                                }
                                #else
                                .focusable(true) { isFocused in
                                    if isFocused {
                                        print("[Reader] focusable focus rect idx=\(idx) region=\(region.id)")
                                        focusedParagraphID = region.id
                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) { focusScale = 1.04 }
                                    } else if focusedParagraphID == region.id {
                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) { focusScale = 1.0 }
                                    }
                                }
                                #endif
                                .accessibilityLabel(region.text)
                        }
                    }
                }
            }
            .allowsHitTesting(true)
        }
    }

    // MARK: Dimmed Backdrop with Focus Hole
    private var dimLayer: some View {
        GeometryReader { _ in
            let isActive = focusedParagraphID != nil
            Canvas { context, size in
                let dimOpacity: Double = isActive ? 0.3 : 0.0
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color.black.opacity(dimOpacity)))

                // Cut holes for the focused paragraph
                if let focused = regions.first(where: { $0.id == focusedParagraphID }),
                   let pdfView = pdfViewRef,
                   let page = pdfView.document?.page(at: focused.pageIndex) {
                    var holePath = Path()
                    let scale = focusScale
                    for r in focused.rectsInPageSpace {
                        let vr = pdfView.convert(r, from: page)
                        let scaled = scaleRect(vr, factor: scale)
                        holePath.addRoundedRect(in: scaled, cornerSize: CGSize(width: 6, height: 6))
                    }
                    context.blendMode = .destinationOut
                    context.fill(holePath, with: .color(.white))
                }
            }
            .animation(.easeInOut(duration: 0.15), value: focusedParagraphID)
            .animation(.easeInOut(duration: 0.15), value: pdfViewRef)
            .allowsHitTesting(false)
        }
    }

    private func scaleRect(_ rect: CGRect, factor: CGFloat) -> CGRect {
        guard factor != 1 else { return rect }
        let cx = rect.midX
        let cy = rect.midY
        let newW = rect.width * factor
        let newH = rect.height * factor
        return CGRect(x: cx - newW / 2, y: cy - newH / 2, width: newW, height: newH)
    }

    private func overlayRectsFor(region: ParagraphRegion) -> [CGRect]? {
        guard let pdfView = pdfViewRef,
              let page = pdfView.document?.page(at: region.pageIndex) else { return nil }
        let rects = region.rectsInPageSpace.map { pdfView.convert($0, from: page) }
        if rects.isEmpty { print("[Reader][WARN] overlay rects empty for region page=\(region.pageIndex) textLen=\(region.text.count)") }
        return rects
    }

    private func computeParagraphsIfNeeded() {
        if regions.isEmpty {
            regions = extractor.extractParagraphs(from: document)
        }
    }

    // MARK: Paging
    private func goToNextPage() {
        guard let pdfView = pdfViewRef else { return }
        if pdfView.canGoToNextPage { pdfView.goToNextPage(nil) }
    }

    private func goToPreviousPage() {
        guard let pdfView = pdfViewRef else { return }
        if pdfView.canGoToPreviousPage { pdfView.goToPreviousPage(nil) }
    }

    // Compute PDFView-space rects for each visual line in a paragraph region
    private func lineRectsFor(region: ParagraphRegion) -> [CGRect] {
        guard let pdfView = pdfViewRef,
              let page = pdfView.document?.page(at: region.pageIndex) else { return [] }
        guard region.nsRange.length > 0, let sel = page.selection(for: region.nsRange) else { return [] }
        let lines = sel.selectionsByLine()
        return lines.map { pdfView.convert($0.bounds(for: page), from: page) }
            .filter { !$0.isNull && !$0.isEmpty }
    }

    // Compute per-line durations based on WPM and simple word counts with clamping and punctuation polish
    private func durationsFor(lines: [PDFSelection], wpm: Double) -> [TimeInterval] {
        let wps = max(1.0, wpm) / 60.0
        var out: [TimeInterval] = []
        out.reserveCapacity(lines.count)
        for sel in lines {
            let text = (sel.attributedString?.string ?? sel.string ?? "")
            let words = text.split { $0.isWhitespace || $0.isNewline }
            var dur = Double(words.count) / max(wps, 0.01)
            // clamp 0.75s ... 4.0s
            dur = min(max(dur, 0.75), 4.0)
            if let last = text.trimmingCharacters(in: .whitespacesAndNewlines).last, ".?!:;".contains(last) {
                dur *= 1.15
            }
            out.append(dur)
        }
        return out
    }

    private func startHighlight(for region: ParagraphRegion) {
        print("[Reader] Start highlight paragraph page=\(region.pageIndex) range=\(region.nsRange) textLen=\(region.text.count)")
        guard let pdfView = pdfViewRef, let page = pdfView.document?.page(at: region.pageIndex) else { return }
        guard region.nsRange.length > 0, let sel = page.selection(for: region.nsRange) else { return }
        let lineSels = sel.selectionsByLine()
        lineDurations = durationsFor(lines: lineSels, wpm: wpm)
        print("[Reader] lines=\(lineSels.count) durations=\(lineDurations)")
        if lineSels.isEmpty { print("[Reader][WARN] No line selections; highlight will not run") }
        currentLineIndex = 0
        lineProgress = 0
        isRunning = !lineDurations.isEmpty
        lastTick = Date()
    }

    private func stopHighlight() {
        isRunning = false
        currentLineIndex = 0
        lineProgress = 0
        lineDurations = []
    }

    private func advanceToNextLineOrParagraph() {
        print("[Reader] advance requested line=\(currentLineIndex)")
        guard let focused = focusedParagraphID, let idx = regions.firstIndex(where: { $0.id == focused }) else { return }
        if currentLineIndex + 1 < lineDurations.count {
            currentLineIndex += 1
            lineProgress = 0
            lastTick = Date()
            print("[Reader] advance to next line idx=\(currentLineIndex)")
        } else {
            // Auto-advance to next paragraph
            let nextIndex = regions.index(after: idx)
            if nextIndex < regions.count {
                let nextRegion = regions[nextIndex]
                focusedParagraphID = nextRegion.id
                startHighlight(for: nextRegion)
                print("[Reader] advance to next paragraph index=\(nextIndex)")
            } else {
                stopHighlight()
                print("[Reader] end of document or regions; stopping highlight")
            }
        }
    }
}

// MARK: - Preview (requires a bundled sample PDF to actually render)
#Preview("PDF Reader", windowStyle: .automatic) {
    let sampleDoc = PDFDocument() // Replace with a real PDFDocument in your app
    PDFReaderView(pdfViewRef: .constant(nil), document: sampleDoc)
        .frame(minWidth: 600, minHeight: 400)
}

#endif

