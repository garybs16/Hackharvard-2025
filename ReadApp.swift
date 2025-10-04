import SwiftUI
import UniformTypeIdentifiers
import PDFKit
import Combine

#if canImport(AppKit)
import AppKit
typealias PlatformImage = NSImage
#elseif canImport(UIKit)
import UIKit
typealias PlatformImage = UIImage
#endif

@main
struct ReadARLandingApp: App {
    var body: some SwiftUI.Scene {
        WindowGroup {
            LandingScreen()
        }
        
        #if os(macOS) || os(visionOS)
        WindowGroup("PDF Viewer", id: "pdf-viewer") {
            PDFViewerWindow()
        }
        #endif
    }
}

// MARK: - Landing Screen

struct LandingScreen: View {
    @State private var showPreview = false
    @State private var showDocumentPicker = false
    @State private var showPDFViewer = false
    #if os(macOS) || os(visionOS)
    @Environment(\.openWindow) private var openWindow
    #endif

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {

                // Hero Section
                VStack(spacing: 24) {
                    // Icon with enhanced design
                    ZStack {
                        // Outer glow
                        RoundedRectangle(cornerRadius: 28)
                            .fill(LinearGradient(
                                gradient: Gradient(colors: [.indigo.opacity(0.3), .purple.opacity(0.2), .pink.opacity(0.1)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 120, height: 120)
                            .blur(radius: 20)
                        
                        // Main icon background
                        RoundedRectangle(cornerRadius: 28)
                            .fill(LinearGradient(
                                gradient: Gradient(colors: [.indigo, .purple, .pink]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 100, height: 100)
                            .shadow(color: .purple.opacity(0.3), radius: 25, x: 0, y: 12)
                            .shadow(color: .indigo.opacity(0.2), radius: 40, x: 0, y: 20)

                        EyeGlyph()
                            .frame(width: 44, height: 44)
                            .foregroundColor(.white)
                            .shadow(radius: 4)
                    }
                    .padding(.top, 20)

                    // Title Section with enhanced typography
                    VStack(spacing: 12) {
                        Text("ReadAR")
                            .font(.system(size: 48, weight: .black, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    gradient: Gradient(colors: [.indigo, .purple]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )

                        Text("Helping every mind read clearly — one word at a time.")
                            .font(.title2.weight(.medium))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    }
                }
                .padding(.bottom, 8)

                // Enhanced Badges
                HStack(spacing: 16) {
                    PillBadge(color: .indigo, label: "Dyslexia", symbol: "brain.head.profile")
                    PillBadge(color: .pink, label: "ADHD", symbol: "circle.hexagongrid")
                    PillBadge(color: .green, label: "AI-Powered", symbol: "sparkles")
                }

                // Features
                FeatureCardVisual()

                // Enhanced CTA Button
                VStack(spacing: 16) {
                    Button(action: {
                        showDocumentPicker = true
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "doc.fill")
                                .imageScale(.medium)
                            Text("Start Reading Experience")
                                .font(.title3.weight(.bold))
                            Image(systemName: "arrow.right")
                                .imageScale(.medium)
                        }
                        .padding(.vertical, 18)
                        .padding(.horizontal, 32)
                        .foregroundColor(.white)
                        .background(
                            Capsule().fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [.indigo, .purple, .pink]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .purple.opacity(0.4), radius: 20, x: 0, y: 10)
                            .shadow(color: .indigo.opacity(0.3), radius: 35, x: 0, y: 15)
                        )
                    }
                    .fileImporter(
                        isPresented: $showDocumentPicker,
                        allowedContentTypes: [.pdf],
                        allowsMultipleSelection: false
                    ) { result in
                        handlePDFSelection(result)
                    }
                    
                    Button("View Demo") {
                        showPreview = true
                    }
                    .font(.headline)
                    .foregroundColor(.indigo)
                    .sheet(isPresented: $showPreview) {
                        ReaderPreview()
                    }
                    .sheet(isPresented: $showPDFViewer) {
                        #if os(iOS)
                        PDFViewerSheet()
                        #endif
                    }

                    Text("Upload a PDF to start reading with enhanced features.")
                        .font(.subheadline)
                        .foregroundColor(.secondary.opacity(0.7))
                        .padding(.top, 4)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
        }
        .background(
            ZStack {
                // Primary gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        .white,
                        .indigo.opacity(0.03),
                        .purple.opacity(0.02),
                        .pink.opacity(0.01)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                // Subtle overlay pattern
                LinearGradient(
                    gradient: Gradient(colors: [
                        .clear,
                        .indigo.opacity(0.02),
                        .clear
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .ignoresSafeArea()
        )
    }
    
    private func handlePDFSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            // Store the PDF URL globally for the PDF viewer
            PDFManager.shared.loadPDF(from: url)
            
            #if os(macOS) || os(visionOS)
            // Open the PDF viewer window on macOS and visionOS
            openWindow(id: "pdf-viewer")
            #else
            // On iOS, show a sheet with the PDF viewer
            showPDFViewer = true
            #endif
            
        case .failure(let error):
            print("Failed to select PDF: \(error)")
        }
    }
}

// MARK: - PDF Manager

class PDFManager: ObservableObject {
    static let shared = PDFManager()
    
    @Published var pdfDocument: PDFDocument?
    @Published var pageImages: [PlatformImage] = []
    @Published var isLoading = false
    
    private init() {}
    
    func loadPDF(from url: URL) {
        isLoading = true
        pageImages = []
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let document = PDFDocument(url: url) else {
                DispatchQueue.main.async {
                    self?.isLoading = false
                }
                return
            }
            
            let pageCount = document.pageCount
            var images: [PlatformImage] = []
            
            for pageIndex in 0..<pageCount {
                if let page = document.page(at: pageIndex) {
                    let pageRect = page.bounds(for: .mediaBox)
                    let scaleFactor: CGFloat = 2.0 // High resolution
                    let scaledSize = CGSize(
                        width: pageRect.width * scaleFactor,
                        height: pageRect.height * scaleFactor
                    )
                    
                    #if canImport(AppKit)
                    if let image = page.thumbnail(of: scaledSize, for: .mediaBox) {
                        images.append(image)
                    }
                    #elseif canImport(UIKit)
                    let image = page.thumbnail(of: scaledSize, for: .mediaBox)
                    images.append(image)
                    #endif
                }
            }
            
            DispatchQueue.main.async {
                self?.pdfDocument = document
                self?.pageImages = images
                self?.isLoading = false
            }
        }
    }
}

// MARK: - PDF Viewer Window

#if os(macOS) || os(visionOS)
struct PDFViewerWindow: View {
    @ObservedObject private var pdfManager = PDFManager.shared
    @State private var columns = 3
    @State private var spacing: CGFloat = 20
    
    var body: some View {
        NavigationView {
            Group {
                if pdfManager.isLoading {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading PDF...")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                } else if pdfManager.pageImages.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No PDF loaded")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("Please upload a PDF from the main window")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                } else {
                    ScrollView {
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: columns),
                            spacing: spacing
                        ) {
                            ForEach(pdfManager.pageImages.indices, id: \.self) { index in
                                PDFPageView(
                                    image: pdfManager.pageImages[index],
                                    pageNumber: index + 1
                                )
                            }
                        }
                        .padding(spacing)
                    }
                }
            }
            .navigationTitle(pdfManager.pdfDocument?.documentURL?.lastPathComponent ?? "PDF Viewer")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    HStack {
                        Text("Columns:")
                            .font(.caption)
                        
                        Picker("Columns", selection: $columns) {
                            ForEach(1...6, id: \.self) { count in
                                Text("\(count)").tag(count)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 60)
                    }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 800, minHeight: 600)
        #elseif os(visionOS)
        .frame(minWidth: 1000, minHeight: 700)
        #endif
    }
}
#else
struct PDFViewerWindow: View {
    var body: some View {
        Text("PDF Viewer not available on this platform")
    }
}
#endif

// MARK: - iOS PDF Viewer Sheet

#if os(iOS)
struct PDFViewerSheet: View {
    @ObservedObject private var pdfManager = PDFManager.shared
    @State private var columns = 2
    @State private var spacing: CGFloat = 16
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Group {
                if pdfManager.isLoading {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading PDF...")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                } else if pdfManager.pageImages.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No PDF loaded")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("Please try uploading the PDF again")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                } else {
                    ScrollView {
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: columns),
                            spacing: spacing
                        ) {
                            ForEach(pdfManager.pageImages.indices, id: \.self) { index in
                                PDFPageView(
                                    image: pdfManager.pageImages[index],
                                    pageNumber: index + 1
                                )
                            }
                        }
                        .padding(spacing)
                    }
                }
            }
            .navigationTitle(pdfManager.pdfDocument?.documentURL?.lastPathComponent ?? "PDF Viewer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack {
                        Text("Columns:")
                            .font(.caption)
                        
                        Picker("Columns", selection: $columns) {
                            ForEach(1...3, id: \.self) { count in
                                Text("\(count)").tag(count)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 120)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundColor(.indigo)
                }
            }
        }
    }
}
#endif

// MARK: - PDF Page View

struct PDFPageView: View {
    let image: PlatformImage
    let pageNumber: Int
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .shadow(
                        color: .black.opacity(isHovered ? 0.2 : 0.1),
                        radius: isHovered ? 20 : 12,
                        x: 0,
                        y: isHovered ? 8 : 4
                    )
                    .scaleEffect(isHovered ? 1.02 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: isHovered)
                
                #if canImport(AppKit)
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(8)
                #elseif canImport(UIKit)
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(8)
                #endif
            }
            #if os(macOS)
            .onHover { hovering in
                isHovered = hovering
            }
            #endif
            
            Text("Page \(pageNumber)")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                )
        }
        .contextMenu {
            Button("View Full Size") {
                // Future: Open full-size view
            }
            Button("Extract Text") {
                // Future: Extract text from this page
            }
        }
    }
}

// MARK: - Components

struct PillBadge: View {
    var color: Color
    var label: String
    var symbol: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .imageScale(.medium)
                .foregroundColor(color)
            Text(label)
                .font(.callout.weight(.bold))
                .foregroundColor(color)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            Capsule()
                .fill(color.opacity(0.08))
                .overlay(
                    Capsule()
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    color.opacity(0.3),
                                    color.opacity(0.1)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: color.opacity(0.15), radius: 8, x: 0, y: 4)
        )
    }
}

struct FeatureCardVisual: View {
    let items: [(Color, String, String, String)] = [
        (.blue, "Eye tracking", "Dynamic text highlight", "eye.fill"),
        (.purple, "Focus modes", "Line • Word • Syllable", "scope"),
        (.green, "Word lookup", "Tap to define / speak", "book.fill"),
        (.orange, "Narration", "Read-aloud sync", "speaker.wave.3.fill"),
        (.teal, "Accessibility", "Dyslexia & ADHD", "accessibility")
    ]

    var body: some View {
        VStack(spacing: 24) {
            // Styled header
            HStack {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundColor(.indigo)
                
                Text("Key Features")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundColor(.indigo)
                
                Spacer()
            }
            .padding(.horizontal, 8)

            VStack(spacing: 20) {
                // First rows with pairs
                let pairCount = items.count / 2
                ForEach(0..<pairCount, id: \.self) { row in
                    HStack(spacing: 20) {
                        FeatureBullet(
                            color: items[row * 2].0,
                            title: items[row * 2].1,
                            subtitle: items[row * 2].2,
                            iconName: items[row * 2].3
                        )
                        
                        FeatureBullet(
                            color: items[row * 2 + 1].0,
                            title: items[row * 2 + 1].1,
                            subtitle: items[row * 2 + 1].2,
                            iconName: items[row * 2 + 1].3
                        )
                    }
                }
                
                // Center the last item if odd count
                if items.count % 2 == 1 {
                    HStack {
                        Spacer()
                        FeatureBullet(
                            color: items.last!.0,
                            title: items.last!.1,
                            subtitle: items.last!.2,
                            iconName: items.last!.3
                        )
                        .frame(maxWidth: 200) // Constrain width for centered item
                        Spacer()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
    }
}

struct FeatureBullet: View {
    var color: Color
    var title: String
    var subtitle: String
    var iconName: String
    
    @State private var isShining = false

    var body: some View {
        VStack(spacing: 20) {
            // Metallic Icon with shine animation
            ZStack {
                // Base tinted background
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                color.opacity(0.15),
                                color.opacity(0.25),
                                color.opacity(0.10)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        color.opacity(0.4),
                                        color.opacity(0.2),
                                        color.opacity(0.1)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: color.opacity(0.25), radius: 12, x: 0, y: 6)
                    .shadow(color: color.opacity(0.1), radius: 24, x: 0, y: 12)
                
                // SF Symbol Icon with metallic effect
                Image(systemName: iconName)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                color,
                                color.opacity(0.7),
                                color
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .white.opacity(0.3), radius: 1, x: 0, y: 1)
                
                // Animated shine overlay
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: .clear, location: 0.0),
                                .init(color: .white.opacity(0.3), location: 0.4),
                                .init(color: .white.opacity(0.6), location: 0.5),
                                .init(color: .white.opacity(0.3), location: 0.6),
                                .init(color: .clear, location: 1.0)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                    .mask(
                        Image(systemName: iconName)
                            .font(.system(size: 24, weight: .medium))
                    )
                    .opacity(isShining ? 1.0 : 0.0)
                    .animation(
                        Animation.easeInOut(duration: 2.0)
                            .repeatForever(autoreverses: true)
                            .delay(Double.random(in: 0...2)),
                        value: isShining
                    )
            }
            .onAppear {
                isShining = true
            }
            
            // Enhanced Text content
            VStack(spacing: 10) {
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text(subtitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 0)
        }
        .padding(.vertical, 28)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, minHeight: 180)
        .background(
            ZStack {
                // Main background with enhanced gradient
                RoundedRectangle(cornerRadius: 28)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                color.opacity(0.04),
                                color.opacity(0.08),
                                color.opacity(0.03)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Border with gradient
                RoundedRectangle(cornerRadius: 28)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                color.opacity(0.2),
                                color.opacity(0.1),
                                color.opacity(0.05)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            }
            .shadow(color: color.opacity(0.12), radius: 20, x: 0, y: 8)
            .shadow(color: color.opacity(0.06), radius: 40, x: 0, y: 20)
        )
    }
}

// MARK: - Reader Preview (demo-only)

struct ReaderPreview: View {
    @Environment(\.dismiss) private var dismiss
    @State private var highlightIndex = 0
    private let lines = [
        "Spatial reading with dynamic line highlight.",
        "Tap a line to focus it visually.",
        "Syllable view available in full app.",
        "Adjust font and spacing for comfort."
    ]

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Text("Reading Preview")
                        .font(.title.weight(.bold))
                        .foregroundColor(.primary)
                    
                    Text("Experience ReadAR's intelligent highlighting")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)

                // Enhanced reading area
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(lines.indices, id: \.self) { i in
                        Text(lines[i])
                            .font(.title3.weight(.medium))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 16)
                            .padding(.horizontal, 20)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        i == highlightIndex 
                                        ? LinearGradient(
                                            gradient: Gradient(colors: [
                                                .yellow.opacity(0.15),
                                                .orange.opacity(0.1)
                                            ]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                        : LinearGradient(
                                            gradient: Gradient(colors: [
                                                .clear,
                                                .clear
                                            ]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(
                                                i == highlightIndex 
                                                ? .yellow.opacity(0.3)
                                                : .gray.opacity(0.1),
                                                lineWidth: i == highlightIndex ? 2 : 1
                                            )
                                    )
                            )
                            .scaleEffect(i == highlightIndex ? 1.02 : 1.0)
                            .animation(.easeInOut(duration: 0.2), value: highlightIndex)
                            .onTapGesture { 
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    highlightIndex = i 
                                }
                            }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.05), radius: 20, x: 0, y: 10)
                )
                .padding(.horizontal, 20)

                Spacer()
                
                // Instructions
                Text("Tap any line to highlight and focus")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 20)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundColor(.indigo)
                }
            }
        }
    }
}

// MARK: - Eye Glyph (vector icon)

struct EyeGlyph: View {
    var body: some View {
        ZStack {
            EyeOutline().stroke(lineWidth: 1.8)
            Circle().fill(Color.white).frame(width: 24, height: 24)
        }
    }
}

struct EyeOutline: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        let a = CGPoint(x: 0.05*w, y: 0.5*h)
        let b = CGPoint(x: 0.5*w, y: 0.1*h)
        let c = CGPoint(x: 0.95*w, y: 0.5*h)
        let d = CGPoint(x: 0.5*w, y: 0.9*h)
        p.move(to: a)
        p.addQuadCurve(to: c, control: b)
        p.addQuadCurve(to: a, control: d)
        return p
    }
}
