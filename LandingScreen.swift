import SwiftUI
import PDFKit
import UniformTypeIdentifiers

struct LandingScreen: View {
    @State private var showPreview = false
    @State private var showDocumentPicker = false
    @ObservedObject private var pdfManager = PDFManager.shared
    @State private var showThumbnails = false
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 32) {
                    Hero(geometry: geometry)
                    FeatureCardVisual()
                    callToAction
                }
                .padding(.horizontal, max(28, geometry.size.width * 0.05))
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
            }
        }
        .background(background)
        .overlay(
            Group {
                if pdfManager.isExtractingText {
                    HStack(spacing: 10) {
                        ProgressView(value: pdfManager.extractionProgress)
                            .progressViewStyle(.linear)
                            .frame(width: 180)
                        Text("Preparing text… \(Int(pdfManager.extractionProgress * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding()
                }
            }, alignment: .bottom
        )
        .fullScreenCover(isPresented: $showThumbnails) {
            if let doc = pdfManager.pdfDocument {
                ThumbnailPickerScreen(document: doc, useGrid: true)
                    .ignoresSafeArea()
            } else {
                ZStack { Color.black.ignoresSafeArea(); ProgressView().tint(.white) }
            }
        }
    }

    private var background: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [.white, .indigo.opacity(0.03), .purple.opacity(0.02), .pink.opacity(0.01)]), startPoint: .top, endPoint: .bottom)
            LinearGradient(gradient: Gradient(colors: [.clear, .indigo.opacity(0.02), .clear]), startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        .ignoresSafeArea()
    }

    private var callToAction: some View {
        VStack(spacing: 16) {
            Button(action: { showDocumentPicker = true }) {
                HStack(spacing: 12) {
                    Image(systemName: "doc.fill").imageScale(.medium)
                    Text("Start Reading Experience").font(.title3.weight(.bold))
                    Image(systemName: "arrow.right").imageScale(.medium)
                }
                .padding(.vertical, 18)
                .padding(.horizontal, 32)
                .foregroundColor(.white)
                .background(
                    Capsule().fill(
                        LinearGradient(gradient: Gradient(colors: [.indigo, .purple, .pink]), startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .shadow(color: .purple.opacity(0.4), radius: 20, x: 0, y: 10)
                    .shadow(color: .indigo.opacity(0.3), radius: 35, x: 0, y: 15)
                )
            }
            .fileImporter(isPresented: $showDocumentPicker, allowedContentTypes: [.pdf], allowsMultipleSelection: false) { result in
                handlePDFSelection(result)
            }

            Button("View Demo") { showPreview = true }
                .font(.headline)
                .foregroundColor(.indigo)
                .sheet(isPresented: $showPreview) { ReaderPreview() }

            Text("Upload a PDF to start reading with enhanced features.")
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.7))
                .padding(.top, 4)
                .multilineTextAlignment(.center)
        }
    }

    private func handlePDFSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let pickedURL = urls.first else { return }

            var stopAccess = false
            if pickedURL.startAccessingSecurityScopedResource() { stopAccess = true }
            defer { if stopAccess { pickedURL.stopAccessingSecurityScopedResource() } }

            do {
                // Copy into our sandbox (tmp) to avoid provider permission issues on device
                let fm = FileManager.default
                let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
                let destURL = tmpDir.appendingPathComponent(UUID().uuidString).appendingPathExtension("pdf")
                // Remove if exists (shouldn't) then copy
                _ = try? fm.removeItem(at: destURL)
                try fm.copyItem(at: pickedURL, to: destURL)

                let data = try Data(contentsOf: destURL, options: [.mappedIfSafe])
                PDFManager.shared.loadPDF(data: data)

                #if os(visionOS)
                openWindow(id: "pdf-browser")
                #else
                DispatchQueue.main.async { showThumbnails = true }
                #endif
            } catch {
                print("Failed to read/copy PDF data: \(error)")
            }
        case .failure(let error):
            print("Failed to select PDF: \(error)")
        }
    }
}

private struct Hero: View {
    let geometry: GeometryProxy
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                RoundedRectangle(cornerRadius: 28)
                    .fill(LinearGradient(gradient: Gradient(colors: [.indigo.opacity(0.3), .purple.opacity(0.2), .pink.opacity(0.1)]), startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 120, height: 120)
                    .blur(radius: 20)
                RoundedRectangle(cornerRadius: 28)
                    .fill(LinearGradient(gradient: Gradient(colors: [.indigo, .purple, .pink]), startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 100, height: 100)
                    .shadow(color: .purple.opacity(0.3), radius: 25, x: 0, y: 12)
                    .shadow(color: .indigo.opacity(0.2), radius: 40, x: 0, y: 20)
                EyeGlyph().frame(width: 44, height: 44).foregroundColor(.white).shadow(radius: 4)
            }
            .padding(.top, 20)
            VStack(spacing: 12) {
                Text("ReadAR")
                    .font(.system(size: min(48, geometry.size.width * 0.08), weight: .black, design: .rounded))
                    .foregroundStyle(LinearGradient(gradient: Gradient(colors: [.indigo, .purple]), startPoint: .leading, endPoint: .trailing))
                Text("Helping every mind read clearly — one word at a time.")
                    .font(.title2.weight(.medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
        }
        .padding(.bottom, 8)
        BadgesRow(geometry: geometry)
    }
}

private struct BadgesRow: View {
    let geometry: GeometryProxy
    var body: some View {
        let badgeLayout = geometry.size.width > 600 ? AnyLayout(HStackLayout(spacing: 16)) : AnyLayout(VStackLayout(spacing: 12))
        return AnyView(badgeLayout {
            PillBadge(color: .indigo, label: "Dyslexia", symbol: "brain.head.profile")
            PillBadge(color: .pink, label: "ADHD", symbol: "circle.hexagongrid")
            PillBadge(color: .green, label: "AI-Powered", symbol: "sparkles")
        })
    }
}

struct PillBadge: View {
    var color: Color
    var label: String
    var symbol: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol).imageScale(.medium).foregroundColor(color)
            Text(label).font(.callout.weight(.bold)).foregroundColor(color)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            Capsule()
                .fill(color.opacity(0.08))
                .overlay(
                    Capsule().stroke(LinearGradient(gradient: Gradient(colors: [color.opacity(0.3), color.opacity(0.1)]), startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
                )
                .shadow(color: color.opacity(0.15), radius: 8, x: 0, y: 4)
        )
    }
}

//
//  LandingScreen.swift
//  ReadAR
//
//  Created by Eason Ying on 10/4/25.
//


struct ThumbnailPickerScreen: View {
    let document: PDFDocument
    var useGrid: Bool = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow
    @State private var selectedPage: Int? = nil
    @State private var pdfViewRef: PDFView? = nil

    var body: some View {
        ZStack {
            Group {
                if useGrid {
                    PDFThumbnailGridView(document: document) { index in selectedPage = index }
                } else {
                    PDFThumbnailBrowserView(document: document) { index in
                        selectedPage = index
                    }
                }
            }
            .ignoresSafeArea()

            if let pageIndex = selectedPage {
                Color.clear
                    .onAppear {
                        // Update selection and open a new window showing this page
                        PDFManager.shared.selectPage(pageIndex)
                        openWindow(value: PageOpenRequest(pageIndex: pageIndex))
                        selectedPage = nil
                        dismiss()
                    }
            }

            // Close button
            VStack {
                HStack { Spacer(); Button(action: { dismiss() }) { Image(systemName: "xmark.circle.fill").font(.system(size: 28)).foregroundStyle(.white, .black.opacity(0.3)) }.padding() }
                Spacer()
            }
        }
    }
}

