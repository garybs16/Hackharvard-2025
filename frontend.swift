//
// Gaze-lite (no eye-tracking entitlement required)
// visionOS-only demo that provides a simulated gaze + optional center reticle
//

import SwiftUI
import Combine

// =========================================================
// MARK: - Public API (View modifier)
// =========================================================

/// Tracks a "gaze-like" point and writes it to the provided binding (in view coordinates).
/// This does NOT use real eye tracking (no entitlement required).
/// It simulates a smooth point so you can build & test UI/logic consistently.
struct GazeLite: ViewModifier {
    @Binding var point: CGPoint?
    private let engine = SimulatedGaze.shared

    func body(content: Content) -> some View {
        content
            .onAppear { engine.start() }
            .onReceive(engine.publisher) { p in point = p }
            .onDisappear { engine.stop() }
    }
}

extension View {
    /// Attach simulated "gaze-like" tracking to any view.
    func gazeLite(_ point: Binding<CGPoint?>) -> some View {
        self.modifier(GazeLite(point: point))
    }
}

// =========================================================
// MARK: - Simulated Gaze Engine
// =========================================================

final class SimulatedGaze {
    static let shared = SimulatedGaze()

    private let subject = PassthroughSubject<CGPoint?, Never>()
    private var timer: AnyCancellable?

    var publisher: AnyPublisher<CGPoint?, Never> { subject.eraseToAnyPublisher() }

    private init() {}

    func start() {
        guard timer == nil else { return }
        var t: CGFloat = 0
        // 30 FPS circular motion in a logical 1000×1000 space
        timer = Timer.publish(every: 1.0/30.0, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                t += 0.05
                let x = 500 + 250 * CGFloat(sin(t))
                let y = 500 + 250 * CGFloat(cos(t))
                self.subject.send(CGPoint(x: x, y: y))
            }
    }

    func stop() {
        timer?.cancel()
        timer = nil
        subject.send(nil)
    }
}

// =========================================================
// MARK: - Optional: Head-center reticle for “look forward” UX
// (Purely visual: a fixed reticle in the center of your view.
//  Use with hand gestures / taps to “select what you’re looking at”.)
// =========================================================

struct CenterReticle: View {
    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(.white.opacity(0.6), lineWidth: 2)
                .frame(width: 22, height: 22)
            Circle()
                .fill(.white.opacity(0.15))
                .frame(width: 8, height: 8)
        }
        .shadow(radius: 6)
        .accessibilityLabel("Center reticle")
        .accessibilityHidden(false)
    }
}

// =========================================================
// MARK: - Demo View (runs immediately)
// =========================================================

struct GazeLiteDemoView: View {
    @State private var gaze: CGPoint?
    @State private var showReticle = true

    // Map 1000×1000 logical space → actual view size
    private func mapToView(_ p: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: p.x * (size.width/1000), y: p.y * (size.height/1000))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(colors: [.black, .gray.opacity(0.6)],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                VStack(spacing: 8) {
                    Text("👁️ Gaze-lite (no entitlement)")
                        .foregroundColor(.white).font(.system(size: 28, weight: .bold))
                    Text("Red dot is simulated. Use this to build & test UI without eye-tracking.")
                        .foregroundColor(.white.opacity(0.85)).font(.callout)
                }
                .padding(.top, 28)
                .frame(maxHeight: .infinity, alignment: .top)

                // decor crosshair
                Rectangle().fill(Color.white.opacity(0.06)).frame(width: 2)
                Rectangle().fill(Color.white.opacity(0.06)).frame(height: 2)

                if showReticle {
                    CenterReticle()
                        .frame(width: 30, height: 30)
                }

                if let g = gaze {
                    let mapped = mapToView(g, in: geo.size)
                    Circle()
                        .fill(.red)
                        .frame(width: 22, height: 22)
                        .shadow(radius: 8)
                        .position(mapped)
                        .animation(.easeOut(duration: 0.05), value: mapped)
                }

                VStack(spacing: 10) {
                    Toggle("Show center reticle", isOn: $showReticle)
                        .toggleStyle(.switch)
                        .tint(.white)
                        .labelsHidden()
                        .padding(10)
                        .background(.ultraThinMaterial, in: Capsule())

                    // Example “select” area to show you can build interactions without gaze APIs
                    Button {
                        // perform an action (e.g., snap the red dot to center)
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            gaze = CGPoint(x: 500, y: 500)
                        }
                    } label: {
                        Label("Center dot", systemImage: "scope")
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 24)
            }
            .gazeLite($gaze)
        }
    }
}

// =========================================================
#if os(visionOS)
// MARK: - Minimal App (delete this @main if integrating into your project)
// =========================================================
@main
struct GazeLiteDemoApp: App {
    var body: some Scene {
        WindowGroup {
            GazeLiteDemoView()
        }
        .windowStyle(.plain)
    }
}
#endif
