import SwiftUI
import PDFKit

// MARK: - PDF Page Thumbnail as SwiftUI View
struct PDFPageImageView: View {
    let page: PDFPage

    var body: some View {
        GeometryReader { geo in
            let bounds = page.bounds(for: .mediaBox)
            let scale = max(geo.size.width / max(bounds.width, 1), geo.size.height / max(bounds.height, 1))
            let targetSize = CGSize(width: bounds.width * scale, height: bounds.height * scale)
            #if canImport(UIKit)
            let image = page.thumbnail(of: targetSize, for: .mediaBox)
            Image(uiImage: image)
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .aspectRatio(contentMode: .fit)
            #elseif canImport(AppKit)
            let image = page.thumbnail(of: targetSize, for: .mediaBox)
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .aspectRatio(contentMode: .fit)
            #else
            Color.clear
            #endif
        }
    }
}

// MARK: - PDFKit PDFView Wrapper
#if canImport(UIKit)
import UIKit

struct PDFViewWrapper: UIViewRepresentable {
    let document: PDFDocument
    var pageIndex: Int = 0
    var resetID: UUID? = nil
    var scaleSet: (scale: CGFloat, id: UUID)? = nil

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .clear
        pdfView.document = document
        if let scaleTuple = scaleSet { pdfView.scaleFactor = scaleTuple.scale }
        goToPage(index: pageIndex, in: pdfView)
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        if pdfView.document !== document {
            pdfView.document = document
        }
        goToPage(index: pageIndex, in: pdfView)
        if let scaleTuple = scaleSet { pdfView.scaleFactor = scaleTuple.scale }
    }

    private func goToPage(index: Int, in pdfView: PDFView) {
        guard let doc = pdfView.document else { return }
        let clamped = max(0, min(index, doc.pageCount - 1))
        if let page = doc.page(at: clamped) {
            pdfView.go(to: page)
        }
    }
}

#elseif canImport(AppKit)
import AppKit

struct PDFViewWrapper: NSViewRepresentable {
    let document: PDFDocument
    var pageIndex: Int = 0
    var resetID: UUID? = nil
    var scaleSet: (scale: CGFloat, id: UUID)? = nil

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .clear
        pdfView.document = document
        if let scaleTuple = scaleSet { pdfView.scaleFactor = scaleTuple.scale }
        goToPage(index: pageIndex, in: pdfView)
        return pdfView
    }

    func updateNSView(_ pdfView: PDFView, context: Context) {
        if pdfView.document !== document {
            pdfView.document = document
        }
        goToPage(index: pageIndex, in: pdfView)
        if let scaleTuple = scaleSet { pdfView.scaleFactor = scaleTuple.scale }
    }

    private func goToPage(index: Int, in pdfView: PDFView) {
        guard let doc = pdfView.document else { return }
        let clamped = max(0, min(index, doc.pageCount - 1))
        if let page = doc.page(at: clamped) {
            pdfView.go(to: page)
        }
    }
}
#endif
