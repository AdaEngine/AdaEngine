import AdaEngine
import Math

@MainActor
enum PhysicsProbeMode: String, CaseIterable {
    case cast = "Shape cast", overlap = "Capsule overlap", area = "Area candidates"
    var next: Self { self == .cast ? .overlap : self == .overlap ? .area : .cast }
}

@MainActor
func setupGeometryQueries(in world: World, session: PhysicsDemoSession) throws {
    world.insertResource(PhysicsDebugOptions.showPhysicsShapes)
    func add(_ name: String, _ shape: Shape2DResource, at position: Vector2 = .zero, layer: UInt64 = 1, sensor: Bool = false) {
        var collision = Collision2DComponent(shapes: [shape], mode: sensor ? .trigger : .default, filter: .init(categoryBitMask: CollisionGroup(rawValue: layer)))
        collision.debugColor = layer == 2 ? Color(1, 0.57, 0.2, 1) : sensor ? Color(0.2, 0.9, 0.5, 1) : Color(0.3, 0.65, 1, 1)
        session.targets.append(world.spawn(name) { collision; Transform(position: Vector3(position, 0)) })
    }
    add("Rounded box", try .generateRoundedBox(width: 1.8, height: 1.2, radius: 0.25), at: [-4, 1.6], layer: 2)
    add("Capsule", try .generateCapsule(from: [0, -0.6], to: [0, 0.6], radius: 0.45), at: [0, 1.6])
    add("Sensor", .generateBox(width: 0.6, height: 2), at: [-2, 1.6], sensor: true)
    add("Segment", try .generateSegment(from: [-0.8, -0.6], to: [0.8, 0.6]), at: [3.7, 1.6])
    add("Rounded triangle", try .generateRoundedPolygon(vertices: [[-0.6, -0.5], [0.6, -0.5], [0, 0.6]], radius: 0.15), at: [1.5, -0.6], layer: 2)
    add("Open chain", try .generateChain(points: [[6, -1.6], [3, -2], [-1, -1.3], [-6, -2]]))
    add("Loop", try .generateChain(points: [[-0.7, -0.5], [0.7, -0.5], [0.7, 0.5], [-0.7, 0.5]], isLoop: true), at: [5, -0.5])
    add("Loose chain segment", try .generateChainSegment(from: [1, 0], to: [-1, 0], ghostStart: [2, 0], ghostEnd: [-2, 0]), at: [-4, -0.6])
    session.queryShape = try .generateCapsule(from: [0, -0.25], to: [0, 0.25], radius: 0.2)
}

@MainActor
func updateGeometryQueries(in world: World, session: PhysicsDemoSession) {
    guard let physics = world.physicsWorld2D, let shape = session.queryShape else {
        return
    }
    session.probeY = 1.6 + (session.scan ? Math.sin(session.elapsed * 0.7) : 0)
    session.probeContact = nil
    do {
        let mask: CollisionGroup = session.blueOnly ? .default : .all
        switch session.probeMode {
        case .cast:
            let hits = try physics.shapeCast(
                shape,
                from: Transform(position: [-7, session.probeY, 0]),
                to: [7, session.probeY],
                query: session.allHits ? .all : .first,
                mask: mask,
                includeSensors: session.querySensors
            )
            session.queryEntities = hits.map(\.entity)
            session.queryPoints = hits.map(\.point)
            session.probeContact = hits.first.map { [-7 + $0.distance, session.probeY] }
        case .overlap:
            session.queryEntities = try physics.overlap(shape, at: Transform(position: [0, session.probeY, 0]), mask: mask, includeSensors: session.querySensors).map(\.entity)
            session.queryPoints = session.queryEntities.compactMap { $0.components[Transform.self]?.position.xy }
        case .area:
            session.queryEntities = physics.overlap(in: Rect(x: -6, y: 0.5, width: 12, height: 2.2), mask: mask, includeSensors: session.querySensors).map(\.entity)
            session.queryPoints = session.queryEntities.compactMap { $0.components[Transform.self]?.position.xy }
        }
        session.rayStatus = "\(session.probeMode.rawValue) · \(session.queryEntities.count) hits: " + session.queryEntities.map(\.name).joined(separator: " · ")
    } catch {
        session.queryEntities.removeAll(); session.queryPoints.removeAll()
        session.rayStatus = "Query failed: \(error)"
    }
}

@System(dependencies: [.after(ExtractPhysicsDebugSystem.self)])
@MainActor
func PhysicsDemoProbeExtract(
    _ state: Extract<Res<PhysicsDemoSession>>,
    _ shapes: ResMut<ExtractedPhysicsDebugShapes>,
    _ data: Res<PhysicsDebugDrawData?>,
    _ sorted: Res<SortedRenderItems<Transparent2DRenderItem>?>
) {
    let session = state.wrappedValue.wrappedValue
    guard session.scene == .queries else {
        return
    }
    if session.probeMode == .area {
        let corners: [Vector2] = [[-6, 0.5], [6, 0.5], [6, 2.7], [-6, 2.7]]
        for index in 0..<4 { shapes.wrappedValue.addLine(from: corners[index], to: corners[(index + 1) % 4], color: .white) }
    } else {
        let x: Float = session.probeMode == .cast ? -7 : 0
        shapes.wrappedValue.addCapsule(from: [x, session.probeY - 0.25], to: [x, session.probeY + 0.25], radius: 0.2, color: .white)
        if session.probeMode == .cast {
            shapes.wrappedValue.addLine(from: [-7, session.probeY], to: [7, session.probeY], color: Color(0.5, 0.6, 0.7, 1))
            if let contact = session.probeContact {
                shapes.wrappedValue.addCapsule(from: contact - [0, 0.25], to: contact + [0, 0.25], radius: 0.2, color: Color(1, 0.85, 0.3, 1))
            }
        }
    }
    session.debugDrawState = "lines=\(shapes.lines.count), vertices=\(data.wrappedValue?.lineVertexBuffer.count ?? -1), items=\(sorted.wrappedValue?.items.items.count ?? -1)"
    for point in session.queryPoints {
        shapes.wrappedValue.addLine(from: point - [0.08, 0], to: point + [0.08, 0], color: .white)
        shapes.wrappedValue.addLine(from: point - [0, 0.08], to: point + [0, 0.08], color: .white)
    }
}

struct PhysicsQueriesDemoPane: View {
    let session: PhysicsDemoSession
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                Button(session.probeMode.rawValue) { session.probeMode = session.probeMode.next }.accessibilityIdentifier("physics-demo.query-kind")
                Button(session.querySensors ? "Include sensors" : "Solids only") { session.querySensors.toggle() }.accessibilityIdentifier("physics-demo.query-sensors")
                Button(session.blueOnly ? "Layer 1 only" : "All layers") { session.blueOnly.toggle() }.accessibilityIdentifier("physics-demo.query-mask")
                Button(session.scan ? "Hold probe" : "Animate probe") { session.scan.toggle() }.accessibilityIdentifier("physics-demo.query-scan")
                if session.probeMode == .cast {
                    Button(session.allHits ? "All hits" : "Nearest hit") { session.allHits.toggle() }.accessibilityIdentifier("physics-demo.query-order")
                }
            }
            Text("White probe queries colored colliders. Area mode shows broad-phase AABB candidates.")
            Text(session.rayStatus)
            SceneView(useSceneCameras: true, make: { configurePhysicsDemo(&$0, session: session) }, updateContent: { _, _ in })
                .frameCaptureLabel("Physics2D Geometry & queries")
                .id(PhysicsDemoScene.queries)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
