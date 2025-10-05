import SwiftUI
import PDFKit
import UIKit

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
    // Text-only paragraph extraction. No geometry; rects are left empty.
    func extractParagraphs(from document: PDFDocument) -> [ParagraphRegion] {
        var results: [ParagraphRegion] = []

        for pageIndex in 0..<document.pageCount {
            guard let _ = document.page(at: pageIndex) else { continue }
            // Attempt to load preformatted content from bundled demo files: page{index+1}Demo.txt
            let resourceName = "page\(pageIndex + 1)Demo"
            if let url = urlForDemoPage(named: resourceName),
               let content = try? String(contentsOf: url, encoding: .utf8) {
                let paragraphs = TextSegmentation.paragraphs(from: content)
                var cursor = 0
                for para in paragraphs {
                    let range = NSRange(location: cursor, length: para.count)
                    cursor += para.count
                    results.append(ParagraphRegion(pageIndex: pageIndex, nsRange: range, text: para, rectsInPageSpace: []))
                }
                continue
            }
            // If file not found, skip (demo-only)
            continue
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
        }
        .onAppear(perform: computeParagraphsIfNeeded)
        .onChange(of: focusedParagraphID) { newValue in
            if newValue == nil {
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
                        ForEach(overlayRects.indices, id: \.self) { idx in
                            let rect = overlayRects[idx]
                            Rectangle()
                                .fill(Color.clear)
                                .frame(width: rect.width, height: rect.height)
                                .position(x: rect.midX, y: rect.midY)
                                .contentShape(Rectangle())
                                #if os(visionOS)
                                .onTapGesture {
                                    focusedParagraphID = region.id
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) { focusScale = 1.04 }
                                }
                                #else
                                .focusable(true) { isFocused in
                                    if isFocused {
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
        return region.rectsInPageSpace.map { pdfView.convert($0, from: page) }
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
}

// MARK: - Preview (requires a bundled sample PDF to actually render)
#Preview("PDF Reader", windowStyle: .automatic) {
    let sampleDoc = PDFDocument() // Replace with a real PDFDocument in your app
    PDFReaderView(pdfViewRef: .constant(nil), document: sampleDoc)
        .frame(minWidth: 600, minHeight: 400)
}

#endif

