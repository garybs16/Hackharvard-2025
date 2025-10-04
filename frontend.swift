// VisionPro Quick Floor Mapper (Swift / visionOS)
// ------------------------------------------------------------
// What this does (hackathon-ready):
// - Lets you walk a space wearing Vision Pro and "drop" Points Of Interest (POIs)
// - Saves POIs (world-space positions) to JSON in the app's Documents folder.
// - Lets you connect nodes into edges to form a simple navgraph (A* pathfinding).
// - Computes a path to a chosen target (e.g., exit) and renders 3D arrows along the path.
//
// Xcode setup:
// 1) File > New > Project... > visionOS App. Product Name: FloorMapper.
// 2) Replace ContentView.swift with this file.
// 3) Add required capabilities in Info.plist or via target settings.
// 4) Build & run on Vision Pro.

import SwiftUI
import RealityKit
import ARKit
import Foundation
import Combine
import simd

// MARK: - Data Models

struct POI: Codable, Identifiable, Hashable {
    let id: String
    var label: String
    var level: String
    var position: SIMD3<Float> // world-space meters
}

enum EdgeType: String, Codable { case walk, stairs, elevator }

struct NavEdge: Codable, Hashable, Identifiable {
    let id: String
    var a: String // node id
    var b: String // node id
    var type: EdgeType
    var cost: Float
}

struct NavGraph: Codable {
    var levels: [String] = ["L0"]
    var nodes: [POI] = []
    var edges: [NavEdge] = []
}

// Internal runtime node for A*
struct Node: Hashable {
    let id: String
    let pos: SIMD2<Float>
}

// MARK: - A* Pathfinding

func aStarPath(nodes: [String: Node], adj: [String: [String]], start: String, goal: String) -> [String] {
    func h(_ a: Node, _ b: Node) -> Float { simd_length(a.pos - b.pos) }
    var open: Set<String> = [start]
    var cameFrom: [String: String] = [:]
    var g: [String: Float] = [start: 0]
    var f: [String: Float] = [start: h(nodes[start]!, nodes[goal]!)]
    while let current = open.min(by: { (f[$0] ?? .infinity) < (f[$1] ?? .infinity) }) {
        if current == goal {
            var path = [current]
            var c = current
            while let p = cameFrom[c] { path.append(p); c = p }
            return path.reversed()
        }
        open.remove(current)
        for nb in adj[current] ?? [] {
            let tentative = (g[current] ?? .infinity) + simd_length(nodes[current]!.pos - nodes[nb]!.pos)
            if tentative < (g[nb] ?? .infinity) {
                cameFrom[nb] = current
                g[nb] = tentative
                f[nb] = tentative + h(nodes[nb]!, nodes[goal]!)
                open.insert(nb)
            }
        }
    }
    return []
}

// MARK: - File I/O

func documentsURL(_ file: String) -> URL {
    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    return docs.appendingPathComponent(file)
}

func saveGraph(_ graph: NavGraph, to filename: String) throws {
    let url = documentsURL(filename)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(graph).write(to: url)
}

func loadGraph(from filename: String) throws -> NavGraph {
    let url = documentsURL(filename)
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode(NavGraph.self, from: data)
}

// MARK: - AR Coordinator

@MainActor
final class ARCoordinator: ObservableObject {
    @Published var graph = NavGraph()
    @Published var currentLevel: String = "L0"
    @Published var lastDroppedNodeID: String? = nil
    @Published var selectedStartID: String? = nil
    @Published var selectedGoalID: String? = nil
    @Published var computedPathIDs: [String] = []
    @Published var isARSessionRunning = false
    
    let arkitSession = ARKitSession()
    let worldTracking = WorldTrackingProvider()
    
    // Scene content
    var rootEntity = Entity()
    var nodeEntities: [String: Entity] = [:]
    var arrowEntities: [Entity] = []
    
    func startTracking() async {
        guard WorldTrackingProvider.isSupported else {
            print("World tracking not supported")
            return
        }
        
        do {
            try await arkitSession.run([worldTracking])
            isARSessionRunning = true
        } catch {
            print("Failed to start ARKit session: \(error)")
        }
    }
    
    func dropNode(label: String) async {
        guard let deviceAnchor = worldTracking.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) else {
            print("No device anchor available")
            return
        }
        
        let transform = deviceAnchor.originFromAnchorTransform
        let camPos = SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
        let forward = SIMD3<Float>(-transform.columns.2.x, -transform.columns.2.y, -transform.columns.2.z)
        let p = camPos + simd_normalize(forward) * 0.8
        
        let poi = POI(id: UUID().uuidString, label: label, level: currentLevel, position: p)
        graph.nodes.append(poi)
        lastDroppedNodeID = poi.id
        placeNodeMarker(poi)
    }
    
    func placeNodeMarker(_ poi: POI) {
        let anchor = AnchorEntity(world: poi.position)
        
        // Sphere marker
        let mesh = MeshResource.generateSphere(radius: 0.06)
        var mat = SimpleMaterial(color: .green, isMetallic: false)
        let sphere = ModelEntity(mesh: mesh, materials: [mat])
        
        // Text label
        let textMesh = MeshResource.generateText(
            poi.label,
            extrusionDepth: 0.01,
            font: .systemFont(ofSize: 0.1),
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byWordWrapping
        )
        var textMat = SimpleMaterial(color: .white, isMetallic: false)
        let textEntity = ModelEntity(mesh: textMesh, materials: [textMat])
        textEntity.position = [0, 0.12, 0]
        
        anchor.addChild(sphere)
        anchor.addChild(textEntity)
        rootEntity.addChild(anchor)
        nodeEntities[poi.id] = anchor
    }
    
    func connectLastToCurrent() {
        guard let last = lastDroppedNodeID, let curr = graph.nodes.last?.id, last != curr else { return }
        let edge = NavEdge(id: UUID().uuidString, a: last, b: curr, type: .walk, cost: 1)
        graph.edges.append(edge)
    }
    
    func clearArrows() {
        for arrow in arrowEntities {
            arrow.removeFromParent()
        }
        arrowEntities.removeAll()
    }
    
    func computePath() {
        clearArrows()
        guard let startID = selectedStartID, let goalID = selectedGoalID else { return }
        
        let levelNodes = graph.nodes.filter { $0.level == currentLevel }
        var nodesDict: [String: Node] = [:]
        for n in levelNodes {
            nodesDict[n.id] = Node(id: n.id, pos: SIMD2<Float>(n.position.x, n.position.z))
        }
        
        var adj: [String: [String]] = [:]
        for e in graph.edges {
            guard let na = graph.nodes.first(where: { $0.id == e.a }),
                  let nb = graph.nodes.first(where: { $0.id == e.b }) else { continue }
            guard na.level == currentLevel, nb.level == currentLevel else { continue }
            adj[e.a, default: []].append(e.b)
            adj[e.b, default: []].append(e.a)
        }
        
        let pathIDs = aStarPath(nodes: nodesDict, adj: adj, start: startID, goal: goalID)
        computedPathIDs = pathIDs
        placeArrowsAlongPath(pathIDs: pathIDs)
    }
    
    func placeArrowsAlongPath(pathIDs: [String], spacing: Float = 1.5) {
        guard pathIDs.count >= 2 else { return }
        
        let idToPOI = Dictionary(uniqueKeysWithValues: graph.nodes.map { ($0.id, $0) })
        var points: [SIMD3<Float>] = []
        
        for (aID, bID) in zip(pathIDs, pathIDs.dropFirst()) {
            guard let A = idToPOI[aID]?.position, let B = idToPOI[bID]?.position else { continue }
            let seg = B - A
            let len = simd_length(seg)
            if len < 0.05 { continue }
            let dir = seg / len
            var t: Float = 0
            while t < len {
                points.append(A + dir * t)
                t += spacing
            }
        }
        
        for (i, p) in points.enumerated() {
            let anchor = AnchorEntity(world: p)
            let arrow = makeArrowEntity()
            
            if i < points.count - 1 {
                let forward = simd_normalize(points[i+1] - p)
                let up = SIMD3<Float>(0, 1, 0)
                let right = simd_normalize(simd_cross(up, forward))
                let correctedUp = simd_cross(forward, right)
                let rotMatrix = simd_float3x3(right, correctedUp, -forward)
                arrow.orientation = simd_quatf(rotMatrix)
            }
            
            anchor.addChild(arrow)
            rootEntity.addChild(anchor)
            arrowEntities.append(anchor)
        }
    }
    
    private func makeArrowEntity() -> ModelEntity {
        let cone = MeshResource.generateCone(height: 0.12, radius: 0.06)
        let shaft = MeshResource.generateBox(size: [0.02, 0.02, 0.20])
        var mat = SimpleMaterial(color: .red, isMetallic: false)
        
        let head = ModelEntity(mesh: cone, materials: [mat])
        head.position = [0, 0, -0.16]
        head.orientation = simd_quatf(angle: .pi, axis: [1, 0, 0])
        
        let body = ModelEntity(mesh: shaft, materials: [mat])
        body.position = [0, 0, 0]
        
        let root = ModelEntity()
        root.addChild(body)
        root.addChild(head)
        return root
    }
    
    func reloadMarkers() {
        // Clear existing markers
        for entity in nodeEntities.values {
            entity.removeFromParent()
        }
        nodeEntities.removeAll()
        
        // Recreate all markers
        for node in graph.nodes {
            placeNodeMarker(node)
        }
    }
}

// MARK: - SwiftUI UI

struct ContentView: View {
    @StateObject private var coord = ARCoordinator()
    @State private var labelText: String = "corner"
    @State private var filename: String = "map.json"
    
    var body: some View {
        ZStack {
            RealityView { content in
                content.add(coord.rootEntity)
                Task {
                    await coord.startTracking()
                }
            }
            .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Level: \(coord.currentLevel)").bold()
                    Button("L0") { coord.currentLevel = "L0" }
                    Button("L1") {
                        coord.currentLevel = "L1"
                        if !coord.graph.levels.contains("L1") {
                            coord.graph.levels.append("L1")
                        }
                    }
                }
                
                HStack {
                    TextField("Label (corner/door/exit)", text: $labelText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 320)
                    Button("Drop Node") {
                        Task { await coord.dropNode(label: labelText) }
                    }
                    Button("Connect Last→This") { coord.connectLastToCurrent() }
                    Button("Clear Arrows") { coord.clearArrows() }
                }
                
                HStack {
                    Menu("Set Start") {
                        ForEach(coord.graph.nodes) { n in
                            Button("\(n.label) • \(n.id.prefix(4))") {
                                coord.selectedStartID = n.id
                            }
                        }
                    }
                    Menu("Set Goal") {
                        ForEach(coord.graph.nodes) { n in
                            Button("\(n.label) • \(n.id.prefix(4))") {
                                coord.selectedGoalID = n.id
                            }
                        }
                    }
                    Button("Compute Path") { coord.computePath() }
                }
                
                HStack {
                    TextField("Filename.json", text: $filename)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 260)
                    Button("Save") {
                        do {
                            try saveGraph(coord.graph, to: filename)
                        } catch {
                            print("Save error: \(error)")
                        }
                    }
                    Button("Load") {
                        do {
                            coord.graph = try loadGraph(from: filename)
                            coord.reloadMarkers()
                        } catch {
                            print("Load error: \(error)")
                        }
                    }
                }
                
                HStack {
                    if let s = coord.selectedStartID {
                        Text("Start: \(s.prefix(6))")
                    }
                    if let g = coord.selectedGoalID {
                        Text("Goal: \(g.prefix(6))")
                    }
                }
                
                Text(coord.isARSessionRunning ? "✓ AR Running" : "Starting AR...")
                    .font(.caption)
                    .foregroundColor(coord.isARSessionRunning ? .green : .orange)
            }
            .padding(16)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}
