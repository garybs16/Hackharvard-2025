// ReaderHost.swift
import SwiftUI
import PDFKit

struct ReaderHost: View {
    @State private var doc: PDFDocument?

    var body: some View {
        Group {
            if let doc {
                ReaderView(document: doc)
            } else {
                VStack(spacing: 12) {
                    Text("Add a PDF named sample.pdf to your app bundle")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    Button("Load Sample PDF") {
                        if let url = Bundle.main.url(forResource: "sample", withExtension: "pdf"),
                           let d = PDFDocument(url: url) {
                            doc = d
                        }
                    }
                }
                .padding()
            }
        }
    }
}
