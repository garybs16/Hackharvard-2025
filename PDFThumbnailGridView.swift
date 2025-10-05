import SwiftUI
import PDFKit

#if os(visionOS)
struct PDFThumbnailGridView: View {
    let document: PDFDocument
    let onSelectPage: (Int) -> Void

    // Appearance
    var thumbWidth: CGFloat = 180
    var spacing: CGFloat = 16

    var body: some View {
        GeometryReader { geo in
            let availableWidth = max(geo.size.width - spacing * 2, thumbWidth)
            let columns = max(1, Int(availableWidth / (thumbWidth + spacing)))
            let gridItems = Array(repeating: GridItem(.flexible(), spacing: spacing, alignment: .top), count: columns)

            ScrollView {
                LazyVGrid(columns: gridItems, alignment: .center, spacing: spacing) {
                    ForEach(0..<document.pageCount, id: \.self) { index in
                        if let page = document.page(at: index) {
                            ThumbnailCell(page: page, pageIndex: index, width: thumbWidth) {
                                onSelectPage(index)
                            }
                        }
                    }
                }
                .padding(spacing)
            }
            .background(Color.clear)
        }
    }
}

private struct ThumbnailCell: View {
    let page: PDFPage
    let pageIndex: Int
    let width: CGFloat
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)
                PageImage(page: page)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            }
            .frame(width: width, height: width * 1.35)

            Text("Page \(pageIndex + 1)")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

private struct PageImage: View {
    let page: PDFPage

    var body: some View {
        GeometryReader { geo in
            let bounds = page.bounds(for: .mediaBox)
            let scale = max(geo.size.width / max(bounds.width, 1), geo.size.height / max(bounds.height, 1))
            let target = CGSize(width: bounds.width * scale, height: bounds.height * scale)
            #if canImport(UIKit)
            let image = page.thumbnail(of: target, for: .mediaBox)
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
            #elseif canImport(AppKit)
            let image = page.thumbnail(of: target, for: .mediaBox)
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
            #else
            Color.clear
            #endif
        }
    }
}
#endif
