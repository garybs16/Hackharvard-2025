import SwiftUI
import Combine

// Conditionally import ARKit/RealityKit only when present to avoid linker issues (e.g., "cannot find strcmp").
#if canImport(ARKit)
import ARKit
#endif

#if canImport(RealityKit)
import RealityKit
#endif

// =========================================================
// MARK: - Public API (View modifier)
// =========================================================

/// Tracks a user's gaze point and writes it to the provided binding (in view coordinates).
/// - Uses real Vision Pro eye tracking when available on visionOS hardware.
/// - Falls back to a smooth simulated gaze otherwise (sim/simulator/macOS/iOS).
struct GazeTracker: ViewModifier {
    @Binding var gazePoint: CGPoint?
    private let eyeTracking = EyeTracking.shared

    func body(content: Content) -> some View {
        content
            .onAppear { eyeTracking.start() }
            .onReceive(eyeTracking.publisher) { newGaze in
                gazePoint = newGaze
            }
            .onDisappear { eyeTracking.stop() }
    }
}

extension View {
    /// Attach gaze tracking to any SwiftUI view.
    /// - Parameter gazePoint: A CGPoint? binding that receives gaze coordinates in the current view's coordinate space (you may map/scale as needed).
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
// MARK: - Simulated Eye Tracking (works everywhere)
// =========================================================

private final class SimulatedEyeTracking: EyeTrackingProtocol {
    static let shared = SimulatedEyeTracking()

    private let subject = PassthroughSubject<CGPoint?, Never>()
    private var timer: AnyCancellable?

    var publisher: AnyPublisher<CGPoint?, Never> {
        subject.eraseToAnyPublisher()
    }

    private init() {}

    func start() {
        guard timer == nil else { return }
        var t: CGFloat = 0
        // 30 FPS simulated gaze moving in a circle around (500, 500)
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
// MARK: - Vision Pro Real Eye Tracking (visionOS only)
// =========================================================

#if os(visionOS) && canImport(ARKit)
@available(visionOS 1.0, *)
private final class VisionRealEyeTracking: EyeTrackingProtocol {
    static let shared = VisionRealEyeTracking()

    private let subject = PassthroughSubject<CGPoint?, Never>()
    private var session: ARKitSession?
    private var task: Task<Void, Never>?

    var publisher: AnyPublisher<CGPoint?, Never> {
        subject.eraseToAnyPublisher()
    }

    private init() {}

    func start() {
        guard task == nil else { return }

        // Attempt to run the ARKitSession with eye gaze device provider.
        let s = ARKitSession()
        session = s

        // Some SDKs expose AREyeGazeDevice; on first run, user must grant eye-tracking permission in visionOS.
        let provider = ARKitSession.DeviceProvider(AREyeGazeDevice())

        // Start session async
        Task {
            do {
                try await s.run([provider])
            } catch {
                // If session fails, stop and emit nil so a caller can decide to fallback.
                print("ARKitSession failed to start: \(error.localizedDescription)")
                await MainActor.run { self.stop() }
                return
            }
        }

        // Stream device events for eye gaze
        task = Task { [weak self] in
            guard let self else { return }
            do {
                for await event in s.deviceEvents(of: AREyeGazeDevice.Event.self) {
                    // event.gazeRay contains origin+direction in 3D (Reality space).
                    // For a simple 2D UI marker, we can map direction x/y to a point.
                    // For precise UI hit-testing, project ray into your scene/camera plane.
                    if let ray = event.gazeRay {
                        // Map direction [-1,1]-ish into a UI-friendly space. You can remap as needed.
                        let px = CGFloat(ray.direction.x)
                        let py = CGFloat(ray.direction.y)
                        // Here we scale to an arbitrary 1000x1000 view space. Adjust to your view size.
                        let mapped = CGPoint(x: (px * 400) + 500, y: (py * 400) + 500)
                        subject.send(mapped)
                    }
                }
            } catch {
                print("Eye-tracking stream error:", error.localizedDescription)
                await MainActor.run { self.stop() }
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        session?.stop()
        session = nil
        subject.send(nil)
    }
}
#endif

// =========================================================
// MARK: - Public Facade (chooses real vs. simulated)
// =========================================================

/// EyeTracking facade exposed to the rest of the app.
/// - On Vision Pro hardware (visionOS) with ARKit available → uses real eye tracking.
/// - Otherwise → uses simulated tracking so the UI continues to function.
final class EyeTracking {
    static let shared: EyeTracking = EyeTracking()

    // Internal engine (backed by real or simulated implementation)
    private let engine: EyeTrackingProtocol

    var publisher: AnyPublisher<CGPoint?, Never> {
        engine.publisher
    }

    private init() {
        #if os(visionOS) && canImport(ARKit)
        if #available(visionOS 1.0, *) {
            // Try to initialize real visionOS eye tracking
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
// MARK: - Optional Demo View (remove if you don't want previews)
// =========================================================

struct GazeDemoView: View {
    @State private var gaze: CGPoint?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Text("👁️ Gaze Tracker")
                .foregroundColor(.white)
                .font(.title2)

            if let g = gaze {
                Circle()
                    .fill(Color.red)
                    .frame(width: 20, height: 20)
                    .position(g)
                    .animation(.easeOut(duration: 0.05), value: g)
            }
        }
        .trackGaze($gaze)
    }
}

#Preview {
    GazeDemoView()
}
