import SwiftUI

@main
struct ReadARLandingApp: App {
    var body: some Scene {
        WindowGroup {
            LandingScreen()
        }
    }
}

// MARK: - Landing Screen

struct LandingScreen: View {
    @State private var showPreview = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 22)
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [.indigo, .purple, .pink]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 92, height: 92)
                        .shadow(color: .purple.opacity(0.25), radius: 22, x: 0, y: 10) // fixed: add x

                    EyeGlyph()
                        .frame(width: 36, height: 36)
                        .foregroundColor(.white)
                        .shadow(radius: 2)
                }
                .padding(.top, 12)

                // Title
                VStack(spacing: 8) {
                    Text("ReadAR")
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundColor(.indigo)

                    Text("Helping every mind read clearly — one word at a time.")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                // Badges
                HStack(spacing: 12) {
                    PillBadge(color: .indigo, label: "Dyslexia", symbol: "brain.head.profile")
                    PillBadge(color: .pink, label: "ADHD", symbol: "circle.hexagongrid")
                    PillBadge(color: .green, label: "AI-Powered", symbol: "sparkles")
                }

                // Features
                FeatureCardVisual()

                // CTA Button (safe syntax)
                Button(action: {
                    showPreview = true
                }) {
                    HStack(spacing: 10) {
                        Text("Start Reading Experience")
                            .font(.headline)
                        Image(systemName: "sparkles")
                            .imageScale(.medium)
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 24)
                    .foregroundColor(.white)
                    .background(
                        Capsule().fill(
                            LinearGradient(
                                gradient: Gradient(colors: [.indigo, .purple, .pink]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .purple.opacity(0.25), radius: 14, x: 0, y: 8) // fixed: add x
                    )
                }
                .sheet(isPresented: $showPreview) {
                    ReaderPreview()
                }

                Text("Demo UI — fewer words, more visuals.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [.white, .indigo.opacity(0.05)]),
                startPoint: .top,
                endPoint: .bottom
            )
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
        .foregroundColor(color)
        .background(
            Capsule()
                .fill(color.opacity(0.12))
                .overlay(Capsule().stroke(color.opacity(0.25), lineWidth: 1))
        )
    }
}

struct FeatureCardVisual: View {
    let items: [(Color, String, String)] = [
        (.blue, "Eye tracking", "Dynamic text highlight"),
        (.purple, "Focus modes", "Line • Word • Syllable"),
        (.green, "Word lookup", "Tap to define / speak"),
        (.orange, "Narration", "Read-aloud sync"),
        (.teal, "Accessibility", "Dyslexia & ADHD")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Key Features:")
                .font(.headline)

            VStack(spacing: 14) {
                ForEach(items.indices, id: \.self) { i in
                    FeatureBullet(color: items[i].0, title: items[i].1, subtitle: items[i].2)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color(.systemBackground).opacity(0.8))
                .shadow(color: .black.opacity(0.06), radius: 20, x: 0, y: 10) // fixed: add x
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
                Text(subtitle).font(.caption).foregroundColor(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.75))
        )
    }
}

// MARK: - Reader Preview (demo-only)

struct ReaderPreview: View {
    @State private var highlightIndex = 0
    private let lines = [
        "Spatial reading with dynamic line highlight.",
        "Tap a line to focus it visually.",
        "Syllable view available in full app.",
        "Adjust font and spacing for comfort."
    ]

    var body: some View {
        VStack(spacing: 18) {
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
                                .fill(i == highlightIndex ? Color.yellow.opacity(0.28) : .clear)
                        )
                        .onTapGesture { highlightIndex = i }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.9))
            )
            .padding(.horizontal)

            Spacer()
        }
        .padding()
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
