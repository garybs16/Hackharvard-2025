import SwiftUI
import PDFKit

public struct PDFViewer: View {
    let data: Data
    public init(data: Data) { self.data = data }
    public var body: some View { PDFKitView(data: data).ignoresSafeArea() }
}

#if os(macOS)
import AppKit
struct PDFKitView: NSViewRepresentable {
    let data: Data
    func makeNSView(context: Context) -> PDFView {
        let v = PDFView()
        v.autoScales = true
        v.displayMode = .singlePageContinuous
        v.displayDirection = .vertical
        v.document = PDFDocument(data: data)
        return v
    }
    func updateNSView(_ v: PDFView, context: Context) {
        v.document = PDFDocument(data: data)
    }
}
#else
import UIKit
struct PDFKitView: UIViewRepresentable {
    let data: Data
    func makeUIView(context: Context) -> PDFView {
        let v = PDFView()
        v.autoScales = true
        v.displayMode = .singlePageContinuous
        v.displayDirection = .vertical
        v.document = PDFDocument(data: data)
        return v
    }
    func updateUIView(_ v: PDFView, context: Context) {
        v.document = PDFDocument(data: data)
    }
}
#endif
