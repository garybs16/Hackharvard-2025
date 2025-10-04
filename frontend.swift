//
// GazeTracker (visionOS-only) — builds in Simulator, uses real eye tracking on device
//

import SwiftUI
import Combine

#if os(visionOS)
import ARKit
#endif

// =========================================================
// MARK: - Public API (View modifier)
// =========================================================

/// Tracks a user's gaze point and writes it to the provided binding (in view coords).
/// On Vision Pro (with entitlement), it uses real eye tracking via ARKit. In the simulator,
/// it falls back to a smooth simulated gaze so you can test layouts and logic.
struct GazeTracker: ViewModifier {
    @Binding var gazePoint: CGPoint?
    private let eyeTracking = EyeTracking.shared

    func body(content: Content) -> some View {
        content
            .onAppear { eyeTracking.start() }
            .onReceive(eyeTracking.publisher) { newGaze in gazePoint = newGaze }
            .onDisappear { eyeTracking.stop() }
    }
}

extension View {
    /// Attach gaze tracking to any SwiftUI view.
    /// - Parameter gazePoint: Binding that receives gaze coordinates in the current view's coordinate space.
    func trackGaze(_ gazePoint: Binding<CGPoint?>) -> some View {
        self.modifier(GazeTracker(gazePoint: gazePoint))
    }
}

// =========================================================
// MARK: - Internal Protocol
// =========================================================

private protocol EyeTrackingProtocol: AnyObject {
    var publisher: AnyPublisher<CGPoint?, Never> { get }
    func start()
    func stop()
}

// =========================================================
/* MARK: - Simulated Eye Tracking (works in Simulator)
   Generates a smooth circular motion at ~30 FPS so UI can be tested without hardware.
*/
// =========================================================

private final class SimulatedEyeTracking: EyeTrackingProtocol {
    static let shared = SimulatedEyeTracking()

    private let subject = PassthroughSubject<CGPoint?, Never>()
    private var timer: AnyCancellable?

    var publisher: AnyPublisher<CGPoint?, Never> { subject.eraseToAnyPublisher() }

    private init() {}

    func start() {
        guard timer == nil else { return }
        var t: CGFloat = 0
        timer = Timer.publish(every: 1.0/30.0, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                t += 0.05
                // 1000x1000 logical space (easy to reason about)
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
// MARK: - Real Eye Tracking (Vision Pro hardware)
// =========================================================

#if os(visionOS)
@available(visionOS 1.0, *)
private final class VisionRealEyeTracking: EyeTrackingProtocol {
    static let shared = VisionRealEyeTracking()

    private let subject = PassthroughSubject<CGPoint?, Never>()
    private var session: ARKitSession?
    private var streamTask: Task<Void, Never>?

    var publisher: AnyPublisher<CGPoint?, Never> { subject.eraseToAnyPublisher() }

    private init() {}

    func start() {
        guard streamTask == nil else { return }

        let s = ARKitSession()
        session = s
        let provider = AREyeGazeDevice() // Requires Eye Tracking entitlement on device

        Task { [weak self] in
            do {
                try await s.run([provider])
                self?.beginStreaming(session: s)
            } catch {
                // If unavailable (missing entitlement/user denied), just stop -> facade will still run (sim fallback).
                print("ARKitSession failed to start eye tracking: \(error)")
                await MainActor.run { self?.stop() }
            }
        }
    }

    private func beginStreaming(session s: ARKitSession) {
        streamTask = Task { [weak self] in
            guard let self else { return }
            do {
                for await event in s.deviceEvents(of: AREyeGazeDevice.Event.self) {
                    guard let ray = event.gazeRay else { continue }
                    // Map the 3D gaze direction into a simple 2D logical space.
                    // NOTE: For true UI hit-testing, intersect the ray with a plane and convert to your view’s coordinates.
                    let px = CGFloat(ray.direction.x)
                    let py = CGFloat(ray.direction.y)
                    let logicalPoint = CGPoint(
                        x: (px * 400) + 500,  // map roughly [-1,1] → [100,900]
                        y: (py * 400) + 500
                    )
                    subject.send(logicalPoint)
                }
            } catch {
                print("Eye-tracking stream error: \(error)")
                await MainActor.run { self.stop() }
            }
        }
    }

    func stop() {
        streamTask?.cancel()
        streamTask = nil
        session?.stop()
        session = nil
        subject.send(nil)
    }
}
#endif

// =========================================================
// MARK: - Public Facade (chooses real vs simulated)
// =========================================================

final class EyeTracking {
    static let shared = EyeTracking()

    private let engine: EyeTrackingProtocol
    var publisher: AnyPublisher<CGPoint?, Never> { engine.publisher }

    private init() {
        #if os(visionOS)
        if #available(visionOS 1.0, *) {
            engine = VisionRealEyeTracking.shared
        } else {
            engine = SimulatedEyeTracking.shared
        }
        #else
        engine = SimulatedEyeTracking.shared
        #endif
    }

    func start() { engine.start() }
    func stop()  { engine.stop()  }
}

// =========================================================
// MARK: - Minimal Demo (runs out of the box)
// - If integrating into your own app, delete the @main App below.
// =========================================================

struct GazeDemoView: View {
    @State private var gaze: CGPoint?

    // Helper to convert logical 1000x1000 space into this view’s size
    private func mapToView(_ p: CGPoint, in size: CGSize) -> CGPoint {
        let sx = size.width  / 1000.0
        let sy = size.height / 1000.0
        return CGPoint(x: p.x * sx, y: p.y * sy)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // background
                LinearGradient(colors: [.black, .gray.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    Text("👁️  Gaze Tracker")
                        .foregroundColor(.white)
                        .font(.system(size: 28, weight: .bold))

                    Text("Red dot follows your gaze (simulated in Simulator).")
                        .foregroundColor(.white.opacity(0.8))
                        .font(.callout)
                }
                .padding(.top, 32)
                .frame(maxHeight: .infinity, alignment: .top)

                // crosshair
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 2)
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 2)

                if let g = gaze {
                    let mapped = mapToView(g, in: geo.size)
                    Circle()
                        .fill(.red)
                        .frame(width: 22, height: 22)
                        .shadow(radius: 8)
                        .position(mapped)
                        .animation(.easeOut(duration: 0.05), value: mapped)
                }
            }
            .trackGaze($gaze)
        }
    }
}

#if os(visionOS)
@main
struct GazeDemoApp: App {
    var body: some Scene {
        WindowGroup {
            GazeDemoView()
        }
        .windowStyle(.plain) // plain or volumetric (not needed for this 2D demo)
    }
}
#endif
