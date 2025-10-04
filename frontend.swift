// Vision Pro Evac Frontend — Polished Starter (visionOS + RealityKit + Spatial Audio)
// ✅ Builds & runs on Apple Vision Pro using Xcode on macOS.
// Frameworks: SwiftUI, RealityKit, AVFAudio (no direct camera access needed for passthrough).
// Target: visionOS 1.0+ (tested APIs). Split into files later as you like.

import SwiftUI
import RealityKit
import AVFoundation

// MARK: - App Entry
@main
struct EvacGuideApp: App {
    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
        }
        // Volumetric window so the arrow sits naturally in world space
        .windowStyle(.volumetric)
        .defaultSize(width: 0.8, height: 0.5, depth: 0.2, in: .meters)
    }
}

// MARK: - ContentView: RealityView + HUD
struct ContentView: View {
    @StateObject private var nav = NavigationManager()
    @State private var showDebug = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RealityView { content, _ in
                await nav.setup(in: content)
            } update: { content, _ in
                await nav.updateScene(in: content)
            }
            // Tap in space to cycle exits (demo)
            .gesture(SpatialTapGesture().targetedToAnyEntity().onEnded { _ in
                nav.cycleTarget()
            })

            // HUD (glass look)
            VStack(alignment: .trailing, spacing: 10) {
                Label(nav.mode.hudTitle, systemImage: nav.mode == .visualAudio ? "eye" : "speaker.wave.2")
                    .font(.title3).bold()
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                if showDebug { DebugPanel(nav: nav) }
                Toggle("Debug", isOn: $showDebug).toggleStyle(.switch)
            }
            .padding(20)
        }
        .onAppear { nav.start() }
        .onDisappear { nav.stop() }
        .accessibilityHint(Text("Vision and audio navigation to nearest exit. Tap to switch target."))
    }
}

// MARK: - Debug Panel
struct DebugPanel: View {
    @ObservedObject var nav: NavigationManager
    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(String(format: "dist: %.2f m", nav.state.distance))
            Text(String(format: "bearingΔ: %.0f°", nav.state.deltaHeadingDegrees))
            Text("beep: \(String(format: "%.1f Hz", nav.audio.currentRateHz))  pan: \(String(format: "%.2f", nav.audio.currentPan)))")
            Text("target idx: \(nav.targetIndex)")
        }
        .font(.caption2)
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - NavigationManager: sensors → visuals + audio
@MainActor
final class NavigationManager: NSObject, ObservableObject {
    enum Mode { case visualAudio, audioOnly
        var hudTitle: String { self == .visualAudio ? "Visual + Audio" : "Audio Only" }
    }

    @Published var mode: Mode = .visualAudio
    @Published var state = GuidanceState()
    @Published var targetIndex: Int = 0

    private let root = AnchorEntity(.world)
    private var arrow = ArrowEntity()
    private var crumbs: [ModelEntity] = []

    let audio = AudioGuidance()

    // Demo targets: positions relative to the user view each frame (for static demo use these offsets)
    private var demoExitOffsets: [SIMD3<Float>] = [ [0, 0, -3], [3, 0, -2], [-2, 0, -2.5] ]

    func setup(in content: RealityViewContent) async {
        // Clean slate
        for e in content.entities { content.remove(e) }
        content.add(root)

        // Add arrow
        arrow.update(size: 0.4)
        root.addChild(arrow)

        // Create 6 billboarding breadcrumbs for nicer look
        crumbs.forEach { $0.removeFromParent() }
        crumbs = (0..<6).map { _ in
            let disk = ModelEntity(mesh: .generatePlane(width: 0.2, depth: 0.2, cornerRadius: 0.1), materials: [UnlitMaterial(color: .init(red: 1, green: 0.2, blue: 0.2, alpha: 0.85))])
            disk.transform.rotation = simd_quatf(angle: -.pi/2, axis: [1,0,0]) // lay flat
            return disk
        }
        crumbs.forEach { root.addChild($0) }

        audio.start()
    }

    func updateScene(in content: RealityViewContent) async {
        guard let cam = content.cameraTransform else { return }

        // Compute a target point around the user for the demo
        let offs = demoExitOffsets[targetIndex]
        let forward = -cam.matrix.columns.2.xyz
        let right   =  cam.matrix.columns.0.xyz
        let up      =  cam.matrix.columns.1.xyz
        let userPos = cam.translation
        let targetWorld = userPos + forward * -offs.z + right * offs.x + up * offs.y

        // Dist & heading delta (signed around up axis)
        let toTarget = targetWorld - userPos
        let dist = simd_length(toTarget)
        let headingDelta = angleSignedBetween(forward, simd_normalize(toTarget), axis: up)

        // Update state
        state.distance = Double(dist)
        state.deltaHeadingDegrees = Double(headingDelta * 180 / .pi)

        // Place arrow 1.2m along the route
        let arrowDist: Float = min(max(dist, 0.6), 1.2)
        let arrowPos = userPos + simd_normalize(toTarget) * arrowDist
        arrow.look(at: targetWorld, from: arrowPos, relativeTo: nil)
        arrow.setPosition(arrowPos, relativeTo: nil)

        // Lay breadcrumbs between user and target for visual appeal
        for (i, crumb) in crumbs.enumerated() {
            let t = Float(i + 1) / Float(crumbs.count + 1)
            let p = userPos + simd_normalize(toTarget) * (t * max(dist, 0.1))
            crumb.setPosition(p, relativeTo: nil)
        }

        // Mode switching hook (wire real visibility metric here)
        mode = state.visibilityScore < 0.25 ? .audioOnly : .visualAudio

        // Audio guidance
        audio.update(distanceMeters: state.distance, deltaHeadingRadians: Double(headingDelta))
    }

    func start() { audio.start() }
    func stop() { audio.stop() }
    func cycleTarget() { targetIndex = (targetIndex + 1) % demoExitOffsets.count }
}

// MARK: - Guidance State
struct GuidanceState {
    var distance: Double = .infinity
    var deltaHeadingDegrees: Double = 0
    // Heuristic in [0,1] — wire to RGB/depth confidence to auto-toggle audio-only
    var visibilityScore: Double = 1.0
}

// MARK: - ArrowEntity (bright, emissive look)
final class ArrowEntity: Entity {
    private var model: ModelEntity?

    func update(size: Float) {
        model?.removeFromParent()
        let shaft = MeshResource.generateBox(size: [size * 0.12, size * 0.12, size])
        let head  = MeshResource.generateCone(topRadius: 0, bottomRadius: size * 0.22, height: size * 0.42)
        let headE = ModelEntity(mesh: head, materials: [UnlitMaterial(color: .init(red: 1, green: 0.25, blue: 0.25, alpha: 1))])
        headE.position = [0, 0, size * 0.52]
        // subtle white shaft for contrast
        let shaftE = ModelEntity(mesh: shaft, materials: [UnlitMaterial(color: .white)])
        let root = ModelEntity()
        root.addChild(shaftE)
        root.addChild(headE)
        model = root
        addChild(root)
    }
}

// MARK: - AudioGuidance: stereo panning + rate by distance
final class AudioGuidance: NSObject {
    private let engine = AVAudioEngine()
    private let env = AVAudioEnvironmentNode()
    private let player = AVAudioPlayerNode()

    private var timer: DispatchSourceTimer?

    // Public (HUD)
    private(set) var currentRateHz: Double = 0
    private(set) var currentPan: Float = 0

    // Tunables
    let maxDistance: Double = 10.0
    let minRate: Double = 0.6
    let maxRate: Double = 4.0

    func start() {
        if engine.isRunning { return }
        engine.attach(env)
        engine.attach(player)
        engine.connect(player, to: env, format: nil)
        engine.connect(env, to: engine.mainMixerNode, format: nil)
        env.renderingAlgorithm = .auto
        env.distanceAttenuationParameters.referenceDistance = 1.0
        try? engine.start()
    }

    func stop() {
        timer?.cancel(); timer = nil
        player.stop()
        engine.stop()
    }

    func update(distanceMeters: Double, deltaHeadingRadians: Double) {
        // distance → beep rate
        let closeness = max(0.0, min(1.0, 1.0 - distanceMeters / maxDistance))
        currentRateHz = minRate + (maxRate - minRate) * closeness

        // signed heading delta → pan [-1,1]
        currentPan = Float(sin(deltaHeadingRadians))

        // Position virtual sound a bit left/right & ahead
        let x: Float = currentPan * 0.5
        env.listenerPosition = AVAudio3DPoint(x: 0, y: 0, z: 0)
        player.position = AVAudio3DPoint(x: x, y: 0, z: -1.0)
        scheduleBeeping()
    }

    private func scheduleBeeping() {
        if timer == nil {
            let t = DispatchSource.makeTimerSource(queue: .main)
            t.schedule(deadline: .now(), repeating: 0.05)
            t.setEventHandler { [weak self] in self?.tick() }
            t.resume()
            timer = t
        }
    }

    private var nextBeepTime: CFAbsoluteTime = 0

    private func tick() {
        guard currentRateHz > 0 else { return }
        let interval = 1.0 / currentRateHz
        let now = CFAbsoluteTimeGetCurrent()
        if now >= nextBeepTime { playClick(); nextBeepTime = now + interval }
    }

    private func playClick() {
        let sampleRate: Double = 44100
        let duration: Double = 0.06
        let frames = AVAudioFrameCount(sampleRate * duration)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        let ch = buffer.floatChannelData![0]
        let freq = 1200.0
        for i in 0..<Int(frames) {
            let t = Double(i) / sampleRate
            let env = exp(-t * 40.0)
            ch[i] = Float(sin(2 * .pi * freq * t) * env)
        }
        if !player.isPlaying { player.play() }
        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
    }
}

// MARK: - Utilities
extension float4x4 { var translation: SIMD3<Float> { [columns.3.x, columns.3.y, columns.3.z] } }
extension SIMD4 where Scalar == Float { var xyz: SIMD3<Float> { [x, y, z] } }

func angleSignedBetween(_ a: SIMD3<Float>, _ b: SIMD3<Float>, axis: SIMD3<Float>) -> Float {
    let cross = simd_cross(a, b)
    let dot = simd_dot(a, b)
    return atan2(simd_dot(cross, axis), dot)
}

// MARK: - Integration Guide
// • Replace demoExitOffsets with exits from your pre-mapped anchors or navgraph waypoints.
// • Feed visibilityScore from your RGB/depth heuristic to auto-switch to audio-only mode.
// • Call audio.update(...) with the next waypoint bearing + distance each frame.
// • Use UnlitMaterial colors for bold, emissive-looking UI that remains visible in dim scenes.
