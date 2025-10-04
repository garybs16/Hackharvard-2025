import SwiftUI

// ===============================
// ReadAR – Landing + Backend Hook
// ===============================

@main
struct ReadARLandingApp: App {
    var body: some Scene {
        WindowGroup {
            LandingScreen()
                .preferredColorScheme(.light)
        }
        #if os(visionOS)
        .windowStyle(.volumetric)
        #endif
    }
}

// MARK: - Config

enum ReadARConfig {
    // Change to your LAN/hosted URL when you deploy the backend from file #2.
    static let apiBase = URL(string: "http://127.0.0.1:5055")!
}

// MARK: - Landing Screen

struct LandingScreen: View {
    @State private var showPreview = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                // App Icon (floating gradient)
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(LinearGradient(colors: [.indigo, .purple, .pink],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 92, height: 92)
                        .shadow(color: .purple.opacity(0.25), radius: 22, y: 10)

                    EyeGlyph()
                        .frame(width: 36, height: 36)
                        .foregroundStyle(.white)
                        .shadow(radius: 2)
                }
                .padding(.top, 12)

                // Title + Tagline (short)
                VStack(spacing: 8) {
                    Text("ReadAR")
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundStyle(.indigo)

                    Text("Helping every mind read clearly — one word at a time.")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                // Badges row (less text, more visual)
                HStack(spacing: 12) {
                    PillBadge(color: .indigo,    label: "Dyslexia",     symbol: "brain.head.profile")
                    PillBadge(color: .pink,      label: "ADHD",         symbol: "circle.hexagongrid")
                    PillBadge(color: .green,     label: "AI-Powered",   symbol: "sparkles")
                }
                .padding(.top, 2)

                // Feature card that mirrors your Figma bullets w/ colored dots
                FeatureCardVisual()

                // CTA button
                Button {
                    showPreview = true
                } label: {
                    HStack(spacing: 10) {
                        Text("Start Reading Experience")
                            .font(.headline)
                        Image(systemName: "sparkles")
                            .imageScale(.medium)
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 24)
                    .foregroundStyle(.white)
                    .background(
                        Capsule().fill(
                            LinearGradient(colors: [.indigo, .purple, .pink],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .shadow(color: .purple.opacity(0.25), radius: 14, y: 8)
                    )
                }
                .buttonStyle(.plain)
                .padding(.bottom, 4)
                .sheet(isPresented: $showPreview) {
                    ReaderPreview() // mini “experience” so judges see flow
                        .presentationDetents([.medium, .large])
                }

                Text("Demo UI — fewer words, more visuals.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(maxWidth: 780)
            .frame(maxWidth: .infinity)
        }
        .background(
            LinearGradient(colors: [.white, .indigo.opacity(0.05)],
                           startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
        )
    }
}

// MARK: - Components

struct PillBadge: View {
    var color: Color
    var label: String
    var symbol: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).imageScale(.small)
            Text(label).font(.callout.weight(.semibold))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .foregroundStyle(color)
        .background(
            Capsule()
                .fill(color.opacity(0.12))
                .overlay(Capsule().stroke(color.opacity(0.25), lineWidth: 1))
        )
    }
}

// Visual “Key Features” card with dot bullets like your screenshot
struct FeatureCardVisual: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Key Features:")
                .font(.headline)

            VStack(alignment: .leading, spacing: 14) {
                BulletRow(color: .blue,    title: "Eye tracking simulation", subtitle: "Dynamic text highlighting")
                BulletRow(color: .purple,  title: "Multiple focus modes",    subtitle: "Full • Line • Word • Syllable")
                BulletRow(color: .green,   title: "Interactive word lookup", subtitle: "Definitions & pronunciation")
                BulletRow(color: .orange,  title: "Voice narration",         subtitle: "Adjustable reading speed")
                BulletRow(color: .teal,    title: "Accessibility modes",     subtitle: "Dyslexia & ADHD presets")
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.6), lineWidth: 1))
                .shadow(color: .black.opacity(0.06), radius: 20, y: 10)
        )
    }
}

struct BulletRow: View {
    var color: Color
    var title: String
    var subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Reader Preview + real definition hook

struct ReaderPreview: View {
    @State private var highlightIndex: Int = 0
    private let lines = [
        "Spatial reading with dynamic line highlight.",
        "Tap any word to define it and hear it aloud.",
        "Syllable mode adds subtle separators.",
        "Adjust font and spacing for comfort."
    ]

    var body: some View {
        VStack(spacing: 18) {
            RoundedRectangle(cornerRadius: 12)
                .fill(.thinMaterial)
                .frame(height: 6)
                .padding(.top, 10)
                .opacity(0.6)

            Text("Reading Preview")
                .font(.title3.weight(.semibold))

            ReaderDemoBlock(lines: lines, highlightIndex: $highlightIndex)
                .padding(.horizontal)

            Spacer()
        }
        .padding()
        .background(LinearGradient(colors: [.white, .indigo.opacity(0.05)],
                                   startPoint: .top, endPoint: .bottom))
    }
}

struct ReaderDemoBlock: View {
    let lines: [String]
    @Binding var highlightIndex: Int
    @State private var showingDefinition = false
    @State private var definitionText = "Loading…"

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(lines.indices, id: \.self) { i in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    // Simple word buttons (tap → define)
                    ForEach(lines[i].split(separator: " ").map(String.init), id: \.self) { w in
                        Button {
                            Task {
                                definitionText = "Loading…"
                                if let def = await DefinitionService.shared.define(w) {
                                    definitionText = "“\(def.word)” — \(def.definition)"
                                } else {
                                    definitionText = "No definition found."
                                }
                                showingDefinition = true
                            }
                        } label: {
                            Text(w)
                                .font(.body)
                                .foregroundStyle(.primary)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(i == highlightIndex ? Color.yellow.opacity(0.25) : .clear)
                )
                .onTapGesture { highlightIndex = i }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.white.opacity(0.85))
        )
        .sheet(isPresented: $showingDefinition) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Definition")
                    .font(.title2.weight(.bold))
                Text(definitionText)
                    .font(.title3)
                Button("Close") { showingDefinition = false }
                    .padding(.top, 8)
            }
            .padding(24)
            .presentationDetents([.medium])
        }
    }
}

// MARK: - Backend API service (calls file #2)

struct DefinitionDTO: Decodable {
    let word: String
    let definition: String
}

final class DefinitionService {
    static let shared = DefinitionService()
    private init() {}

    func define(_ word: String) async -> DefinitionDTO? {
        await fetch(endpoint: "define", word: word)
    }
    func explain(_ sentence: String) async -> DefinitionDTO? {
        await fetch(endpoint: "explain", word: sentence)
    }

    private func fetch(endpoint: String, word: String) async -> DefinitionDTO? {
        let url = ReadARConfig.apiBase.appending(path: "/api/\(endpoint)")
        var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "q", value: word)]
        guard let final = comps.url else { return nil }

        do {
            var req = URLRequest(url: final)
            req.timeoutInterval = 8
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            return try JSONDecoder().decode(DefinitionDTO.self, from: data)
        } catch {
            return nil
        }
    }
}

// MARK: - Eye glyph (for the icon)

struct EyeGlyph: View {
    var body: some View {
        ZStack {
            EyeOutline().stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
            Circle().fill(.white).frame(width: 24, height: 24)
        }
    }
}
struct EyeOutline: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        let a = CGPoint(x: 0.05*w, y: 0.5*h)
        let b = CGPoint(x: 0.5*w,  y: 0.1*h)
        let c = CGPoint(x: 0.95*w, y: 0.5*h)
        let d = CGPoint(x: 0.5*w,  y: 0.9*h)
        p.move(to: a)
        p.addQuadCurve(to: c, control: b)
        p.addQuadCurve(to: a, control: d)
        return p
    }
}
