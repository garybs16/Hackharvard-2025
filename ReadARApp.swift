import SwiftUI

@main
struct ReadARLandingApp: App {
    var body: some Scene {
        WindowGroup {
            LandingScreen()
                .preferredColorScheme(.light)
        }
    }
}

// MARK: - Landing Screen

struct LandingScreen: View {
    @State private var showPreview = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                // App Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.indigo, .purple, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 92, height: 92)
                        .shadow(color: .purple.opacity(0.25), radius: 22, y: 10)

                    EyeGlyph()
                        .frame(width: 36, height: 36)
                        .foregroundStyle(.white)
                        .shadow(radius: 2)
                }
                .padding(.top, 12)

                // Title + Tagline
                VStack(spacing: 8) {
                    Text("ReadAR")
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundStyle(.indigo)

                    Text("Helping every mind read clearly — one word at a time.")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                // Badges row
                HStack(spacing: 12) {
                    PillBadge(color: .indigo,    label: "Dyslexia",   symbol: "brain.head.profile")
                    PillBadge(color: .pink,      label: "ADHD",       symbol: "circle.hexagongrid")
                    PillBadge(color: .green,     label: "AI-Powered", symbol: "sparkles")
                }
                .padding(.top, 2)

                // Feature card
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
                    ReaderPreview()
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

// Feature Card
struct FeatureCardVisual: View {
    let items: [(Color, String, String)] = [
        (.blue,   "Eye tracking", "Dynamic text highlighting"),
        (.purple, "Focus modes",  "Line • Word • Syllable"),
        (.green,  "Word lookup",  "Definitions & speak"),
        (.orange, "Narration",    "Read-aloud sync"),
        (.teal,   "Accessibility","Dyslexia & ADHD")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Key Features:")
                .font(.headline)

            VStack(spacing: 14) {
                ForEach(items.indices, id: \.self) { i in
                    FeatureBullet(color: items[i].0,
                                  title: items[i].1,
                                  subtitle: items[i].2)
                }
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

struct FeatureBullet: View {
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
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Reader Preview (demo only)

struct ReaderPreview: View {
    @State private var highlightIndex: Int = 0
    private let lines = [
        "Spatial reading with dynamic line highlight.",
        "Tap words to see a definition popup.",
        "Syllable mode adds separators.",
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

            VStack(alignment: .leading, spacing: 10) {
                ForEach(lines.indices, id: \.self) { i in
                    Text(lines[i])
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
            .padding(.horizontal)

            Spacer()
        }
        .padding()
        .background(
            LinearGradient(colors: [.white, .indigo.opacity(0.05)],
                           startPoint: .top, endPoint: .bottom)
        )
    }
}

// MARK: - Eye glyph

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
