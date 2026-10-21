import AdaEngine
import Math
import Observation

/// The same scenes run in the interactive window, offscreen capture and deterministic validation.
enum PhysicsDemoScene: String, CaseIterable {
    case raycast, events, queries, mechanisms, characters, advanced
    var gravity: Vector2 { self == .raycast || self == .queries ? .zero : [0, -9.81] }
}

@MainActor
@Observable
final class PhysicsDemoSession: Resource {
    let scene: PhysicsDemoScene
    let rendering: Bool
    var advanced = PhysicsAdvancedState()
    var mechanismOwners: [Entity] = []
    var mechanismStarts: [Vector2] = []
    var reverseRequested = false
    var breakRequested = false
    var driveDirection: Float = 1
    var moverDirection: Float = 1
    var connectedJoints = 0
    var jointBreaks = 0
    var character: Entity?
    var crate: Entity?
    var platform: Entity?
    var characterMode = CharacterController2DMode.query
    var moveDirection: Float = 0
    var jumpRequest = false
    var platformDirection: Float = 1
    var debugDrawState = "extract pending"
    var probeMode = PhysicsProbeMode.cast
    var querySensors = true
    var queryShape: Shape2DResource?
    var queryEntities: [Entity] = []
    var queryPoints: [Vector2] = []
    var probeY: Float = 1.6
    var probeContact: Vector2?
    var allHits = true
    var blueOnly = false
    var scan = true
    var elapsed: Float = 0
    var resetRequested = false
    var rayStatus = "Waiting for physics sync"
    var contactBegins = 0
    var contactEnds = 0
    var sensorBegins = 0
    var sensorEnds = 0
    var impacts = 0
    var lastImpactSpeed: Float = 0
    var sensorOccupied = false
    var targets: [Entity] = []
    var markers: [Entity] = []
    var beam: Entity?
    var sensor: Entity?
    var visitor: Entity?
    var falling: Entity?
    var lastHits: [Raycast2DHit] = []

    func resetScene() {
        advanced = PhysicsAdvancedState()
        elapsed = 0
        mechanismOwners.removeAll(); mechanismStarts.removeAll()
        reverseRequested = false; breakRequested = false; driveDirection = 1; moverDirection = 1
        connectedJoints = 0; jointBreaks = 0
        character = nil; crate = nil; platform = nil; moveDirection = 0; jumpRequest = false; platformDirection = 1
        resetRequested = false
        rayStatus = "Waiting for physics sync"
        contactBegins = 0
        contactEnds = 0
        sensorBegins = 0
        sensorEnds = 0
        impacts = 0
        lastImpactSpeed = 0
        sensorOccupied = false
        targets.removeAll()
        markers.removeAll()
        beam = nil
        sensor = nil
        visitor = nil
        falling = nil
        lastHits.removeAll()
        queryEntities.removeAll(); queryPoints.removeAll(); queryShape = nil; probeContact = nil
    }

    init(scene: PhysicsDemoScene, rendering: Bool = true) {
        self.scene = scene
        self.rendering = rendering
    }
}

@MainActor
func configurePhysicsDemo(_ app: inout AppWorlds, session: PhysicsDemoSession) {
    app.addPlugin(TransformPlugin()).addPlugin(InputPlugin()).addPlugin(RenderWorldPlugin())
        .addPlugin(CameraPlugin()).addPlugin(AssetsPlugin()).addPlugin(VisibilityPlugin())
        .addPlugin(SpritePlugin()).addPlugin(Core2DPlugin()).addPlugin(UpscalePlugin())
        .addPlugin(Physics2DPlugin(gravity: session.scene.gravity))
        .addPlugin(PhysicsDemoPlugin(session: session))
}

struct PhysicsDemoPlugin: Plugin {
    let session: PhysicsDemoSession

    func setup(in app: AppWorlds) {
        app.insertResource(session)
            .addSystem(PhysicsDemoStartupSystem.self, on: .startup)
            .addSystem(PhysicsDemoControlsSystem.self, on: .fixedPreUpdate)
            .addSystem(PhysicsDemoFrameSystem.self, on: .postUpdate)
        app.getSubworldBuilder(by: .renderWorld)?.addSystem(PhysicsDemoProbeExtractSystem.self, on: .extract)
    }
}

@System
@MainActor
func PhysicsDemoStartup(_ context: WorldUpdateContext, _ state: Res<PhysicsDemoSession>) {
    let session = state.wrappedValue
    session.resetScene()
    let world = context.world
    if session.rendering {
        var camera = Camera()
        camera.backgroundColor = Color(0.035, 0.055, 0.10, 1)
        world.spawn("Physics camera", bundle: Camera2D(camera: camera, orthographicProjection: OrthographicProjection(scale: 48)))
    }
    if session.scene == .advanced {
        do { try setupAdvanced(in: world, session: session) } catch { session.rayStatus = "Advanced setup failed: \(error)" }
        return
    }
    if session.scene == .mechanisms || session.scene == .characters {
        do {
            if session.scene == .mechanisms { try setupMechanisms(in: world, session: session) } else { try setupCharacters(in: world, session: session) }
        } catch { session.rayStatus = "Setup failed: \(error)" }
        return
    }
    if session.scene == .queries {
        do { try setupGeometryQueries(in: world, session: session) } catch { session.rayStatus = "Geometry failed: \(error)" }
        return
    }
    if session.scene == .raycast {
        for (index, x) in [Float(-3), 0, 3].enumerated() {
            let color: Color = index == 1 ? Color(1, 0.57, 0.20, 1) : Color(0.25, 0.55, 1, 1)
            let entity = world.spawn("Target \(index + 1)") {
                Sprite(tintColor: color, size: [0.8, 3])
                Collision2DComponent(
                    shapes: [.generateBox(width: 0.8, height: 3)],
                    filter: CollisionFilter(categoryBitMask: CollisionGroup(rawValue: index == 1 ? 2 : 1))
                )
                Transform(position: [x, 0, 0])
            }
            session.targets.append(entity)
        }
        session.beam = world.spawn("Ray") {
            Sprite(tintColor: Color(0.3, 1, 0.8, 1), size: [12, 0.035])
            Transform(position: [0, 0, 1])
        }
        for _ in 0..<3 {
            session.markers.append(world.spawn("Hit marker") {
                Sprite(tintColor: .white, size: [0.16, 0.16])
                Transform(position: [0, 50, 2])
            })
        }
    } else {
        world.spawn("Floor") {
            Sprite(tintColor: Color(0.3, 0.4, 0.55, 1), size: [14, 0.5])
            Collision2DComponent(shapes: [.generateBox(width: 14, height: 0.5)])
            Transform(position: [0, -2, 0])
        }
        session.sensor = world.spawn("Sensor") {
            Sprite(tintColor: Color(0.15, 0.6, 0.4, 0.45), size: [3, 3])
            Collision2DComponent(shapes: [.generateBox(width: 3, height: 3)], mode: .trigger)
            Transform(position: [-2, 0.5, -1])
        }
        var visitorBody = PhysicsBody2DComponent(shapes: [.generateBox(width: 0.5, height: 0.5)], mass: 1)
        visitorBody.gravityScale = 0
        visitorBody.linearVelocity = [2.5, 0]
        session.visitor = world.spawn("Sensor visitor") {
            Sprite(tintColor: Color(0.3, 0.75, 1, 1), size: [0.5, 0.5])
            visitorBody
            Transform(position: [-5, 0.5, 1])
        }
        session.falling = world.spawn("Bouncing box") {
            Sprite(tintColor: Color(1, 0.57, 0.2, 1), size: [0.8, 0.8])
            PhysicsBody2DComponent(
                shapes: [.generateBox(width: 0.8, height: 0.8)],
                mass: 1,
                material: .generate(friction: 0.4, restitution: 0.65, density: 1)
            )
            Transform(position: [3, 3, 1])
        }
    }
}

@System
@MainActor
func PhysicsDemoControls(_ context: WorldUpdateContext, _ state: Res<PhysicsDemoSession>, _ time: Res<FixedTime>) {
    let session = state.wrappedValue
    session.elapsed += Float(time.deltaTime)
    if session.scene == .advanced {
        controlAdvanced(in: context.world, session: session)
        return
    }
    if session.scene == .mechanisms {
        controlMechanisms(session)
        return
    }
    if session.scene == .characters {
        controlCharacter(session)
        return
    }
    guard session.scene == .events else {
        return
    }
    if let visitor = session.visitor, (visitor.components[Transform.self]?.position.x ?? 0) > 1.5 {
        visitor.components[PhysicsBody2DComponent.self]?.setPosition([-5, 0.5])
        visitor.components[PhysicsBody2DComponent.self]?.linearVelocity = [2.5, 0]
    }
    if session.resetRequested {
        session.resetRequested = false
        session.falling?.components[PhysicsBody2DComponent.self]?.setPosition([3, 3])
        session.falling?.components[PhysicsBody2DComponent.self]?.linearVelocity = [0, -0.1]
    }
}

@System
@MainActor
func PhysicsDemoFrame(
    _ context: WorldUpdateContext,
    _ state: Res<PhysicsDemoSession>,
    _ begins: Events<CollisionEvents.Began>,
    _ ends: Events<CollisionEvents.Ended>,
    _ hits: Events<CollisionEvents.Hit>,
    _ jointEvents: Events<Joint2DEvents.ThresholdExceeded>
) {
    let session = state.wrappedValue
    for event in begins {
        if event.isSensor { session.sensorBegins += 1; session.sensorOccupied = true } else { session.contactBegins += 1 }
    }
    for event in ends {
        if event.isSensor { session.sensorEnds += 1; session.sensorOccupied = false } else { session.contactEnds += 1 }
    }
    for _ in jointEvents { session.jointBreaks += 1 }
    for event in hits {
        session.impacts += 1; session.lastImpactSpeed = event.approachSpeed
        if session.scene == .advanced { session.advanced.hitPoints = event.contact?.manifold.points.count ?? 0 }
    }
    session.sensor?.components[Sprite.self]?.tintColor = session.sensorOccupied ? Color(0.2, 1, 0.5, 0.8) : Color(0.15, 0.6, 0.4, 0.45)
    if session.scene == .advanced {
        frameAdvanced(in: context.world, session: session)
        return
    }
    if session.scene == .mechanisms {
        session.connectedJoints = session.mechanismOwners.filter { $0.components[PhysicsJoint2DComponent.self]?.isConnected == true }.count
        session.rayStatus = "\(session.connectedJoints) / 9 connected · \(session.jointBreaks) break events · filter box passes through its block"
        return
    }
    if session.scene == .characters {
        updateCharacterStatus(session)
        return
    }
    if session.scene == .queries {
        updateGeometryQueries(in: context.world, session: session)
        return
    }
    guard session.scene == .raycast, let physics = context.world.physicsWorld2D else {
        return
    }
    let start = Vector2(-6, 0)
    let end = Vector2(6, session.scan ? Math.sin(session.elapsed * 0.7) * 3 : 0)
    let hits = physics.raycast(
        from: start,
        to: end,
        query: session.allHits ? .all : .first,
        mask: session.blueOnly ? .default : .all
    )
    session.lastHits = hits
    let description = hits.map { "\($0.entity.name): \((($0.distance * 100).rounded()) / 100) m" }.joined(separator: "  ·  ")
    session.rayStatus = hits.isEmpty ? "No hits" : description
    let translation = end - start
    session.beam?.components[Sprite.self]?.size = Size(width: translation.squaredLength.squareRoot(), height: 0.035)
    session.beam?.components[Transform.self] = Transform(
        rotation: Quat(axis: [0, 0, 1], angle: Math.atan2(translation.y, translation.x)),
        position: Vector3((start + end) / 2, 1)
    )
    for (index, marker) in session.markers.enumerated() {
        marker.components[Transform.self]?.position = index < hits.count ? Vector3(hits[index].point, 2) : [0, 50, 2]
    }
}
