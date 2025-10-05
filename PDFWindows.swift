import SwiftUI
import PDFKit
import UniformTypeIdentifiers

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
    var body: some View {
        NavigationView {
            Group {
                if pdfManager.isLoading {
                    VStack(spacing: 20) {
                        ProgressView().scaleEffect(1.5)
                        Text("Loading PDF...").font(.title2).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let document = pdfManager.pdfDocument {
                    VStack(spacing: 12) {
                        if pdfManager.isExtractingText {
                            HStack(spacing: 12) {
                                ProgressView(value: pdfManager.extractionProgress)
                                    .progressViewStyle(.linear)
                                    .frame(maxWidth: 300)
                                Text("Extracting text… \(Int(pdfManager.extractionProgress * 100))%")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.top, 8)
                        }
                        PDFThumbnailGridView(document: document) { index in
                            openWindow(value: PageOpenRequest(pageIndex: index))
                        }
                        .ignoresSafeArea()
                    }
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "doc.text").font(.system(size: 48)).foregroundColor(.secondary)
                        Text("No PDF loaded").font(.title2).foregroundColor(.secondary)
                        Text("Please upload a PDF from the main window").font(.body).foregroundColor(.secondary).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle(pdfManager.pdfDocument?.documentURL?.lastPathComponent ?? "PDF Browser")
        }
        .frame(minWidth: 800, idealWidth: 1200, maxWidth: .infinity, minHeight: 600, idealHeight: 800, maxHeight: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}

struct PDFPageViewerWindow: View {
    @ObservedObject private var pdfManager = PDFManager.shared
    var initialPageIndex: Int? = nil

    @State private var paragraphFrames: [Int: CGRect] = [:]
    @State private var selectedParagraphIndex: Int? = nil

    private struct ParagraphBoundsPreference: PreferenceKey {
        static var defaultValue: [Int: CGRect] = [:]
        static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
            value.merge(nextValue(), uniquingKeysWith: { $1 })
        }
    }

    var body: some View {
        GeometryReader { geo in
            content(in: geo.size)
        }
    }

    // MARK: - Content Builder
    @ViewBuilder
    private func content(in size: CGSize) -> some View {
        if let document = pdfManager.pdfDocument {
            let pageIndex = clampedPageIndex(in: document)
            let paragraphs = paragraphsForPage(pageIndex, in: document)

            ZStack {
                scrollParagraphs(paragraphs, containerSize: size)
                selectionDimLayer(in: size)
                    .allowsHitTesting(false)
                edgeFades
                    .ignoresSafeArea()
            }
            .onPreferenceChange(ParagraphBoundsPreference.self) { frames in
                paragraphFrames = frames
            }
            .background(Color.clear)
            .ignoresSafeArea()
        } else {
            emptyState
        }
    }

    // MARK: - Subviews
    private var edgeFades: some View {
        VStack {
            LinearGradient(colors: [Color.black.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 120)
                .allowsHitTesting(false)
            Spacer()
            LinearGradient(colors: [.clear, Color.black.opacity(0.35)], startPoint: .top, endPoint: .bottom)
                .frame(height: 120)
                .allowsHitTesting(false)
        }
    }

    private func scrollParagraphs(_ paragraphs: [String], containerSize: CGSize) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(paragraphs.indices, id: \.self) { i in
                    ParagraphBubble(
                        index: i,
                        text: paragraphs[i],
                        isSelected: selectedParagraphIndex == i,
                        width: min(760, containerSize.width * 0.85)
                    ) {
                        selectedParagraphIndex = i
                    }
                    .background(
                        GeometryReader { pGeo in
                            Color.clear
                                .preference(key: ParagraphBoundsPreference.self, value: [i: pGeo.frame(in: .named("readerSpace"))])
                        }
                    )
                }
            }
            .frame(width: min(760, containerSize.width * 0.85), alignment: .leading)
            .padding(.vertical, 60)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .coordinateSpace(name: "readerSpace")
        .background(Color.clear)
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

    // MARK: - Selection Dim Layer
    private func selectionDimLayer(in size: CGSize) -> AnyView {
        guard let sel = selectedParagraphIndex, let rect = paragraphFrames[sel] else {
            return AnyView(EmptyView())
        }
        let view = Canvas { context, canvasSize in
            context.fill(Path(CGRect(origin: .zero, size: canvasSize)), with: .color(Color.black.opacity(0.28)))
            let holePath = Path(roundedRect: rect.insetBy(dx: -6, dy: -6), cornerRadius: 14)
            context.blendMode = .destinationOut
            context.fill(holePath, with: .color(.white))
        }
        .animation(.easeInOut(duration: 0.15), value: selectedParagraphIndex)
        .animation(.easeInOut(duration: 0.15), value: paragraphFrames)
        return AnyView(view)
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

