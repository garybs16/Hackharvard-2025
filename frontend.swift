// VisionPro Floor Mapper — First Floor Only (Swift / visionOS)
// ------------------------------------------------------------
// Minimal, hackathon-friendly tool to RECORD a single-floor map:
// • Drop nodes (corners/doors/exits) while walking
// • Connect nodes into edges (navgraph)
// • Save/Load the floor map JSON (stable across runs for later testing)
// • Simple 2D top‑down mini‑map overlay to visualize nodes/edges (no 3D arrows)
//
// How to use
// 1) Xcode → New → visionOS App → replace ContentView.swift with this file.
// 2) Run on Vision Pro. In the overlay:
//    - Enter a label (e.g., "corner", "door", "exit") and tap "Drop Node" as you move.
//    - Use "Connect Last→This" to add an edge from the previously dropped node to the latest node.
//    - Use the Mini‑Map to confirm shape; hit Save to persist JSON to Documents.
// 3) Later, tap "Load" to reuse the same floor map for testing.
//
// Notes
// • We record world‑space positions but treat them as 2D (x,z). Y is ignored.
// • No multi‑level (stairs) handling; this is strictly first‑floor.
// • No 3D arrows or pathfinding here; this is just the map builder.
// • You can add A* later by reading the saved JSON in your guidance app.

import SwiftUI
import RealityKit
import ARKit
import simd

// MARK: - Data Models (First‑floor only)

struct POI: Codable, Identifiable, Hashable {
    let id: String
    var label: String
    var position: SIMD3<Float> // world meters; we use x,z for 2D
}

enum EdgeType: String, Codable { case walk }

struct NavEdge: Codable, Hashable, Identifiable {
    let id: String
    var a: String // node id
    var b: String // node id
    var type: EdgeType
}

struct FloorMap: Codable {
    var name: String = "FirstFloor"
    var nodes: [POI] = []
    var edges: [NavEdge] = []
}

// MARK: - File I/O (JSON in Documents)

func documentsURL(_ file: String) -> URL {
    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    return docs.appendingPathComponent(file)
}

func saveFloorMap(_ map: FloorMap, to filename: String) throws {
    let url = documentsURL(filename)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(map).write(to: url)
}

func loadFloorMap(from filename: String) throws -> FloorMap {
    let url = documentsURL(filename)
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode(FloorMap.self, from: data)
}

// MARK: - AR/Reality Coordinator (node dropping only)

final class MapperCoordinator: NSObject, ObservableObject, ARSessionDelegate {
    @Published var map = FloorMap()
    @Published var lastDroppedNodeID: String? = nil

    weak var arView: ARView?
    private var nodeAnchors: [String: AnchorEntity] = [:]

    func setup(on view: ARView) {
        self.arView = view
        view.automaticallyConfigureSession = false
        view.environment.sceneUnderstanding.options.insert(.occlusion)
        let config = ARWorldTrackingConfiguration()
        config.sceneReconstruction = .mesh
        config.planeDetection = [.horizontal, .vertical]
        view.session.delegate = self
        view.session.run(config, options: [.resetTracking, .removeExistingAnchors])
    }

    // Drop a node ~0.8 m ahead of the user at current camera height (y ignored in 2D)
    func dropNode(label: String) {
        guard let frame = arView?.session.currentFrame else { return }
        let T = frame.camera.transform
        let camPos = SIMD3<Float>(T.columns.3.x, T.columns.3.y, T.columns.3.z)
        let forward = SIMD3<Float>(-T.columns.2.x, -T.columns.2.y, -T.columns.2.z)
        let p = camPos + normalize(forward) * 0.8
        let poi = POI(id: UUID().uuidString, label: label, position: p)
        map.nodes.append(poi)
        lastDroppedNodeID = poi.id
        placeNodeMarker(poi)
    }

    func placeNodeMarker(_ poi: POI) {
        guard let arView else { return }
        let anchor = AnchorEntity(world: poi.position)
        let mesh = MeshResource.generateSphere(radius: 0.055)
        var mat = SimpleMaterial(color: .green, isMetallic: false)
        let entity = ModelEntity(mesh: mesh, materials: [mat])
        entity.name = "node_\(poi.id)"
        // floating text label
        let text = MeshResource.generateText(poi.label, extrusionDepth: 0.006, font: .systemFont(ofSize: 0.09))
        let textEntity = ModelEntity(mesh: text, materials: [SimpleMaterial(color: .white, isMetallic: false)])
        textEntity.position = [0, 0.11, 0]
        anchor.addChild(entity
