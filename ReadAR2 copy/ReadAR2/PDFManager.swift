import Foundation
import PDFKit
#if os(visionOS)
import UIKit
public typealias PlatformImage = UIImage
#endif
import Combine

final class PDFManager: ObservableObject {
    static let shared = PDFManager()
    
    @Published var pdfDocument: PDFDocument?
    @Published var pageImages: [PlatformImage] = []
    @Published var selectedPageIndex: Int = 0
    @Published var isLoading = false
    @Published var scaleResetTrigger = UUID()
    @Published var scaleSetTrigger: (scale: CGFloat, id: UUID) = (scale: 1.0, id: UUID())
    
    @Published var textPages: [String] = []
    @Published var extractionProgress: Double = 0.0
    @Published var isExtractingText: Bool = false

    private init() {}
    
    func loadPDF(from url: URL) {
        isLoading = true
        extractionProgress = 0.0
        isExtractingText = false
        textPages = []
        selectedPageIndex = 0
        pageImages = []
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let document = PDFDocument(url: url) else {
                DispatchQueue.main.async { self?.isLoading = false }
                return
            }
            self?.generateThumbnails(from: document)
        }
    }
    
    func loadPDF(data: Data) {
        isLoading = true
        extractionProgress = 0.0
        isExtractingText = false
        textPages = []
        selectedPageIndex = 0
        pageImages = []
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let document = PDFDocument(data: data) else {
                DispatchQueue.main.async { self?.isLoading = false }
                return
            }
            self?.generateThumbnails(from: document)
        }
    }
    
    private func generateThumbnails(from document: PDFDocument) {
        let pageCount = document.pageCount
        var images: [PlatformImage] = []
        
        for pageIndex in 0..<pageCount {
            if let page = document.page(at: pageIndex) {
                let pageRect = page.bounds(for: .mediaBox)
                let scaleFactor: CGFloat = 2.0
                let scaledSize = CGSize(width: pageRect.width * scaleFactor, height: pageRect.height * scaleFactor)
                let image = page.thumbnail(of: scaledSize, for: .mediaBox)
                images.append(image)
            }
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.pdfDocument = document
            self?.pageImages = images
            self?.isLoading = false
            // Start text extraction immediately
            self?.startTextExtraction()
        }
    }
    
    private func startTextExtraction() {
        guard let document = self.pdfDocument else { return }
        isExtractingText = true
        extractionProgress = 0.0
        textPages = Array(repeating: "", count: document.pageCount)

        let total = max(document.pageCount, 1)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var extracted: [String] = Array(repeating: "", count: document.pageCount)
            for idx in 0..<document.pageCount {
                autoreleasepool {
                    if let page = document.page(at: idx) {
                        let text = page.attributedString?.string ?? page.string ?? ""
                        extracted[idx] = text
                    }
                    let progress = Double(idx + 1) / Double(total)
                    DispatchQueue.main.async {
                        self?.textPages = extracted
                        self?.extractionProgress = progress
                    }
                }
            }
            DispatchQueue.main.async { [weak self] in
                self?.isExtractingText = false
            }
        }
    }
    
    func selectPage(_ index: Int) { selectedPageIndex = index }
    func resetPageScale() { scaleResetTrigger = UUID() }
    func setPageScale(_ scale: CGFloat) { scaleSetTrigger = (scale: scale, id: UUID()) }
}
//
//  PDFManager.swift
//  ReadAR
//
//  Created by Eason Ying on 10/4/25.
//
