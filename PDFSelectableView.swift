// PDFSelectableView.swift
import SwiftUI
import PDFKit

#if os(iOS)
typealias PlatformViewRepresentable = UIViewRepresentable
typealias TapGestureRecognizer = UITapGestureRecognizer
#else
typealias PlatformViewRepresentable = NSViewRepresentable
typealias TapGestureRecognizer = NSClickGestureRecognizer
#endif

struct PDFSelectableView: PlatformViewRepresentable {
    let document: PDFDocument
    let onParagraphPicked: (String) -> Void

    // MARK: - make/update View
    #if os(iOS)
    func makeUIView(context: Context) -> PDFView {
        let v = configuredPDFView()
        v.addGestureRecognizer(TapGestureRecognizer(target: context.coordinator,
                                                    action: #selector(Coordinator.handleTap(_:))))
        context.coordinator.pdfView = v
        return v
    }

    func updateUIView(_ v: PDFView, context: Context) {
        v.document = document
    }
    #else
    func makeNSView(context: Context) -> PDFView {
        let v = configuredPDFView()
        v.addGestureRecognizer(TapGestureRecognizer(target: context.coordinator,
                                                    action: #selector(Coordinator.handleTap(_:))))
        context.coordinator.pdfView = v
        return v
    }

    func updateNSView(_ v: PDFView, context: Context) {
        v.document = document
    }
    #endif

    private func configuredPDFView() -> PDFView {
        let v = PDFView()
        v.document = document
        v.autoScales = true
        v.displayMode = .singlePageContinuous
        v.displayDirection = .vertical
        v.backgroundColor = .clear
        return v
    }

    // MARK: - Coordinator
    func makeCoordinator() -> Coordinator {
        Coordinator(onParagraphPicked: onParagraphPicked)
    }

    final class Coordinator: NSObject {
        weak var pdfView: PDFView?
        let onParagraphPicked: (String) -> Void

        init(onParagraphPicked: @escaping (String) -> Void) {
            self.onParagraphPicked = onParagraphPicked
        }

        @objc func handleTap(_ gr: TapGestureRecognizer) {
            #if os(iOS)
            guard let v = pdfView, gr.state == .ended else { return }
            let pt = gr.location(in: v)
            #else
            guard let v = pdfView, gr.state == .ended else { return }
            let pt = gr.location(in: v)
            #endif

            guard let page = v.page(for: pt, nearest: true) else { return }
            let pagePoint = v.convert(pt, to: page)

            // Start with the word (fallback to line)
            guard var sel = page.selectionForWord(at: pagePoint) ?? page.selectionForLine(at: pagePoint) else { return }
            sel.extendForLineBoundaries()

            // Expand to paragraph
            if let para = expandToParagraph(from: sel, page: page) {
                v.setCurrentSelection(para, animate: true)
                v.highlightedSelections = [para]
                let text = para.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                onParagraphPicked(text)
            }
        }

        /// Heuristic: grow selection line-by-line until hitting a blank line.
        private func expandToParagraph(from base: PDFSelection, page: PDFPage) -> PDFSelection? {
            guard let full = page.string, let baseStr = base.string else { return base }
            let lines = full.components(separatedBy: .newlines)

            // Map selection range into line indices
            let nsFull = full as NSString
            let baseRange = nsFull.range(of: baseStr)
            if baseRange.location == NSNotFound { return base }

            // Build line ranges
            var lineRanges: [NSRange] = []
            var loc = 0
            for line in lines {
                let r = NSRange(location: loc, length: (line as NSString).length)
                lineRanges.append(r)
                loc += r.length + 1 // + newline
            }

            // Find which line contains selection start
            guard let startIdx = lineRanges.firstIndex(where: { NSIntersectionRange($0, baseRange).length > 0 }) else { return base }
            var first = startIdx
            var last = startIdx

            // Expand up to blank line
            while first > 0, lines[first - 1].trimmingCharacters(in: .whitespaces).isEmpty == false { first -= 1 }
            while last < lines.count - 1, lines[last + 1].trimmingCharacters(in: .whitespaces).isEmpty == false { last += 1 }

            let paraRange = NSUnionRange(lineRanges[first], lineRanges[last])
            let paraText = nsFull.substring(with: paraRange)

            let paraSel = PDFSelection(document: page.document!)
            paraSel?.add(page)
            paraSel?.setString(paraText) // anchors the range within the page text
            return paraSel
        }
    }
}
