import SwiftUI
import PDFKit

// PDFViewer.swift
// A reusable SwiftUI wrapper for displaying PDFs

struct PDFViewer: View {
    let data: Data

    var body: some View {
        PDFKitView(data: data)
            .ignoresSafeArea()
    }
}

// MARK: - UIKit wrapper (for iOS / visionOS)
struct PDFKitView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.document = PDFDocument(data: data)
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        pdfView.document = PDFDocument(data: data)
    }
}
