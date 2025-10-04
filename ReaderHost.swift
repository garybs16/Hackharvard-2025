// ReaderHost.swift
import SwiftUI
import PDFKit

/// Minimal host to try the reader without touching your existing flows.
/// Add a `sample.pdf` to your app bundle (check "Add to targets").
struct ReaderHost: View {
    @State private var doc: PDFDocument?

    var body: some View {
        Group {
            if let doc {
                ReaderView(document: doc)
            } else {
                VStack(spacing: 12) {
                    Text("Tap to load sample.pdf").font(.headline)
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
