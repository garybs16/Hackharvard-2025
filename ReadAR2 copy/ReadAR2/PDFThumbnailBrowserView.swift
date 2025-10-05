import SwiftUI
import PDFKit
import UIKit

#if os(visionOS)
struct PDFThumbnailBrowserView: UIViewRepresentable {
    let document: PDFDocument
    let onSelectPage: (Int) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onSelectPage: onSelectPage) }

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear

        // Backing PDFView (not visible) that drives the thumbnail view
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.isHidden = true

        // Thumbnail view configured to use the backing PDFView
        let thumbs = PDFThumbnailView()
        thumbs.backgroundColor = .clear
        thumbs.pdfView = pdfView
        thumbs.thumbnailSize = CGSize(width: 180, height: 240)
        thumbs.layoutMode = .vertical
        thumbs.contentInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)

        // Add subviews
        container.addSubview(thumbs)
        container.addSubview(pdfView)

        // Auto Layout
        thumbs.translatesAutoresizingMaskIntoConstraints = false
        pdfView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            thumbs.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            thumbs.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            thumbs.topAnchor.constraint(equalTo: container.topAnchor),
            thumbs.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            // Keep pdfView offscreen/hidden but sized
            pdfView.widthAnchor.constraint(equalToConstant: 1),
            pdfView.heightAnchor.constraint(equalToConstant: 1),
            pdfView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            pdfView.topAnchor.constraint(equalTo: container.topAnchor)
        ])

        // Observe page changes on the backing PDFView to detect selection
        context.coordinator.pdfView = pdfView
        NotificationCenter.default.addObserver(context.coordinator,
                                               selector: #selector(Coordinator.pageChanged(_:)),
                                               name: Notification.Name.PDFViewPageChanged,
                                               object: pdfView)
        // Mark initial setup complete to avoid firing on initial load
        context.coordinator.didInitialLoad = true
        DispatchQueue.main.async { context.coordinator.didInitialLoad = false }

        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // Document is constant here; could support updates if needed
    }

    final class Coordinator: NSObject {
        weak var pdfView: PDFView?
        var onSelectPage: (Int) -> Void
        var didInitialLoad: Bool = true

        init(onSelectPage: @escaping (Int) -> Void) {
            self.onSelectPage = onSelectPage
        }

        @objc func pageChanged(_ note: Notification) {
            guard didInitialLoad == false, let pdfView = pdfView, let doc = pdfView.document, let page = pdfView.currentPage else { return }
            let index = doc.index(for: page)
            if index != NSNotFound { onSelectPage(index) }
        }
    }
}
#endif

