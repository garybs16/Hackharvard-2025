import SwiftUI

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

// MARK: - Landing Screen

struct LandingScreen: View {
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
                        .frame(width: 90, height: 90)
                        .shadow(color: .purple.opacity(0.25), radius: 20, y: 10)

                    EyeGlyph()
                        .frame(width: 36, height: 36)
                        .foregroundStyle(.white)
                        .shadow(radius: 2)
                }
                .padding(.top, 12)

                // Title & Tagline (short)
                VStack(spacing: 6) {
                    Text("ReadAR")
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .foregroundStyle(.indigo)
                        .tracking(0.5)

                    Text("Helping every mind read clearly.")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                // Badges
                HStack(spacing: 10) {
                    Badge(color: .indigo.opacity(0.12), stroke: .indigo.opacity(0.25), textColor: .indigo, icon: "brain.head.profile", label: "Dyslexia")
                    Badge(color: .pink.opacity(0.12), stroke: .pink.opacity(0.25), textColor: .pink, icon: "circle.hexagongrid", label: "ADHD")
                    Badge(color: .green.opacity(0.12), stroke: .green.opacity(0.25), textColor: .green, icon: "sparkles", label: "AI")
                }
                .padding(.top, 2)

                // Feature Card (visual, minimal text)
                FeatureCard()

                // CTA
                NavigationButton()
                    .padding(.bottom, 8)

                Text("Demo UI — fewer words, more visuals.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            .frame(maxWidth: 740)
            .frame(maxWidth: .infinity)
        }
        .background(
            LinearGradient(
                colors: [.white, .indigo.opacity(0.05)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }
}

// MARK: - Components

struct Badge: View {
    var color: Color
    var stroke: Color
    var textColor: Color
    var icon: String
    var label: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .imageScale(.small)
            Text(label)
                .font(.callout.weight(.semibold))
        }
        .foregroundStyle(textColor)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .fill(color)
                .overlay(
                    RoundedRectangle(cornerRadius: 999, style: .continuous)
                        .stroke(stroke, lineWidth: 1)
                )
        )
    }
}

struct FeatureCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Key Features")
                .font(.headline)
                .foregroundStyle(.primary)

            // 2x2 Grid of feature tiles (icons + short labels)
            Grid(horizontalSpacing: 14, verticalSpacing: 14) {
                GridRow {
                    FeatureTile(icon: "viewfinder", title: "Gaze highlight", subtitle: "Line • Word")
                    FeatureTile(icon: "text.line.first.and.arrowtriangle.forward", title: "Focus modes", subtitle: "Line • Word • Syllable")
                }
                GridRow {
                    FeatureTile(icon: "book.closed", title: "Tap to define", subtitle: "Meaning • Speak")
                    FeatureTile(icon: "waveform", title: "Voice narration", subtitle: "Sync with focus")
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(.white.opacity(0.6), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.06), radius: 20, y: 10)
        )
    }
}

struct FeatureTile: View {
    var icon: String
    var title: String
    var subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.gradient(colors: [.indigo.opacity(0.12), .purple.opacity(0.12)]))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(.white.opacity(0.7), lineWidth: 1)
                    )
                    .frame(width: 42, height: 42)
                Image(systemName: icon)
                    .foregroundStyle(LinearGradient(colors: [.indigo, .purple], startPoint: .top, endPoint: .bottom))
                    .imageScale(.large)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white.opacity(0.75))
        )
    }
}

struct NavigationButton: View {
    @State private var pressed = false
    var body: some View {
        Button {
            pressed.toggle()
        } label: {
            HStack(spacing: 10) {
                Text("Start Reading Experience")
                    .font(.headline)
                Image(systemName: "arrow.right")
                    .imageScale(.medium)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 22)
            .foregroundStyle(.white)
            .background(
                Capsule().fill(
                    LinearGradient(colors: [.indigo, .purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .shadow(color: .purple.opacity(0.25), radius: 12, y: 6)
            )
            .scaleEffect(pressed ? 0.98 : 1)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: pressed)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $pressed) {
            // Placeholder “experience” screen so judges see a flow
            ReaderPreview()
                .presentationDetents([.medium, .large])
        }
    }
}

// Minimal preview/placeholder to make the CTA do something visual
struct ReaderPreview: View {
    @State private var highlightIndex: Int = 0
    private let lines = [
        "Spatial reading with dynamic line highlight.",
        "Tap words to hear pronunciation and definitions.",
        "Syllable mode uses a subtle separator.",
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
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(i == highlightIndex ? Color.yellow.opacity(0.25) : .clear)
                        )
                        .onTapGesture { highlightIndex = i }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.white.opacity(0.8))
            )
            .padding(.horizontal)

            Spacer()
        }
        .padding()
        .background(LinearGradient(colors: [.white, .indigo.opacity(0.05)], startPoint: .top, endPoint: .bottom))
    }
}

// MARK: - Simple “eye” glyph (vector)
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
