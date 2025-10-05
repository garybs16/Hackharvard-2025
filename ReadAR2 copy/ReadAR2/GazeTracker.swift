import SwiftUI
import Combine

// =========================================================
// MARK: - Gaze Tracker View Modifier
// =========================================================

struct GazeTracker: ViewModifier {
    @Binding var gazePoint: CGPoint?
    private let tracker = SimulatedEyeTracking.shared

    func body(content: Content) -> some View {
        content
            .onAppear { tracker.start() }
            .onReceive(tracker.publisher) { newGaze in
                gazePoint = newGaze
            }
            .onDisappear { tracker.stop() }
    }
}

extension View {
    func trackGaze(_ gazePoint: Binding<CGPoint?>) -> some View {
        self.modifier(GazeTracker(gazePoint: gazePoint))
    }
}

// =========================================================
// MARK: - Simulated Eye Tracking (works everywhere)
// =========================================================

final class SimulatedEyeTracking {
    static let shared = SimulatedEyeTracking()

    private let subject = PassthroughSubject<CGPoint?, Never>()
    private var timer: AnyCancellable?

    var publisher: AnyPublisher<CGPoint?, Never> {
        subject.eraseToAnyPublisher()
    }

    private init() {}

    /// Starts emitting simulated gaze points at ~20 Hz.
    func start() {
        // If already running, do nothing.
        guard timer == nil else { return }

        // Publish a tick on the main run loop and map it to a random CGPoint in unit coordinates (0...1).
        timer = Timer.publish(every: 0.05, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                let x = CGFloat.random(in: 0...1)
                let y = CGFloat.random(in: 0...1)
                self.subject.send(CGPoint(x: x, y: y))
            }
    }

    /// Stops emitting gaze points and clears the current value.
    func stop() {
        timer?.cancel()
        timer = nil
        subject.send(nil)
    }

    deinit {
        timer?.cancel()
        timer = nil
    }
}
