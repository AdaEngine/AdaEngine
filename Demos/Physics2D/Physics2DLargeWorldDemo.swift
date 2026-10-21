import AdaEngine
import Foundation
import Math
import Observation

@MainActor
@Observable
final class PhysicsLargeWorldState {
    let base = PhysicsPosition2D(x: 1_000_000_000.125, y: -999_999_999.75)
    var shifted = false
    var nudgeRequested = false
    var mode = CharacterController2DMode.query
    var direction: Float = 0
    var jumpRequested = false
    var target: Entity?
    var crate: Entity?
    var hinge: Entity?
    var marker: Entity?
    var hit: PhysicsPosition2D?
    var distance: Float = 0
    var probeStart = Vector2.zero
    var probeEnd = Vector2.zero
    var hitLocal: Vector2?
    var contactID: Contact2DID?
    var pointCount = 0
    var status = "Waiting for precise queries"
}

@MainActor
func setupLargeWorld(in world: World, session: PhysicsDemoSession) throws {
    let state = session.largeWorld
    guard let physics = world.physicsWorld2D, physics.setCoordinateOrigin(state.base) else {
        return
    }
    world.insertResource(PhysicsDebugOptions([.showPhysicsShapes, .showJoints]))
    world.spawn("Global floor") {
        Collision2DComponent(shapes: [.generateBox(width: 16, height: 0.4)])
        Sprite(tintColor: Color(0.25, 0.35, 0.5, 1), size: [16, 0.4])
        Transform()
        PhysicsPosition2DComponent(state.base.offset(by: [0, -2.5]))
    }
    for x: Float in [-8, 8] {
        world.spawn("Global boundary") {
            Collision2DComponent(shapes: [.generateBox(width: 0.2, height: 4)])
            Transform()
            PhysicsPosition2DComponent(state.base.offset(by: [x, -0.3]))
        }
    }
    state.target = world.spawn("Millimeter query target") {
        Collision2DComponent(shapes: [.generateBox(width: 0.4, height: 1.2)], filter: CollisionFilter(categoryBitMask: CollisionGroup(rawValue: 8)))
        Sprite(tintColor: Color(0.2, 0.65, 1, 1), size: [0.4, 1.2])
        Transform()
        PhysicsPosition2DComponent(state.base.offset(by: [3, 0.8]))
    }
    state.crate = world.spawn("Global contact box") {
        PhysicsBody2DComponent(shapes: [.generateBox(width: 0.8, height: 0.8)], massProperties: .init(mass: 1, inertia: [0, 0, 1]))
        Sprite(tintColor: Color(1, 0.6, 0.2, 1), size: [0.8, 0.8])
        Transform()
        PhysicsPosition2DComponent(state.base.offset(by: [-1, -1.9]))
    }
    var bob = PhysicsBody2DComponent(shapes: [.generateCircle(radius: 0.8)], massProperties: .init(mass: 1, inertia: [0, 0, 0.2]))
    bob.debugColor = Color(0.5, 1, 0.65, 1); bob.angularVelocity = 1
    let pendulum = world.spawn("Global hinge bob") { bob; Transform(); PhysicsPosition2DComponent(state.base.offset(by: [-3, 0.3])) }
    let descriptor = try PhysicsJoint2DDescriptor.revolute(entity: pendulum, globalAnchor: state.base.offset(by: [-3, 2]))
    state.hinge = world.spawn("Exact global pivot") { PhysicsJoint2DComponent(joint: descriptor) }
    let controller = CharacterController2DComponent(radius: 0.3, height: 1.5)
    session.character = world.spawn("Global character") { controller; Transform(); PhysicsPosition2DComponent(state.base.offset(by: [1, 0])) }
    state.marker = world.spawn("Precise hit marker") {
        Sprite(tintColor: Color(1, 0.85, 0.2, 1), size: [0.12, 0.12])
        Transform(position: [0, 0, 2])
        PhysicsPosition2DComponent(state.base.offset(by: [3, 0.8]))
    }
}

@MainActor
func controlLargeWorld(in world: World, session: PhysicsDemoSession) {
    let state = session.largeWorld
    let origin = state.shifted ? state.base.offset(by: [1000, -500]) : state.base
    if world.physicsWorld2D?.coordinateOrigin != origin { world.physicsWorld2D?.setCoordinateOrigin(origin) }
    if state.nudgeRequested, let target = state.target, let position = target.components[PhysicsPosition2DComponent.self]?.position {
        target.components[PhysicsPosition2DComponent.self]?.position = .init(x: position.x + 0.001, y: position.y)
        state.nudgeRequested = false
    }
    if let player = session.character {
        if player.components[CharacterController2DComponent.self]?.mode != state.mode {
            player.components[CharacterController2DComponent.self]?.mode = state.mode
            player.components[CharacterController2DComponent.self]?.resetMotion = true
        }
        player.components[CharacterController2DComponent.self]?.desiredVelocity = [state.direction * 2, 0]
        if state.jumpRequested { player.components[CharacterController2DComponent.self]?.jumpRequested = true; state.jumpRequested = false }
    }
}

@MainActor
func frameLargeWorld(in world: World, session: PhysicsDemoSession) {
    let state = session.largeWorld
    guard let physics = world.physicsWorld2D, let target = state.target,
        let targetPosition = target.components[PhysicsPosition2DComponent.self]?.position else {
        return
    }
    let start = state.base.offset(by: [-6, 0.8])
    let hit = physics.raycast(from: start, translation: [12, 0], query: .first, mask: CollisionGroup(rawValue: 8)).first
    state.hit = hit?.point; state.distance = hit?.distance ?? 0
    state.probeStart = start.displacement(from: physics.coordinateOrigin)
    state.probeEnd = start.offset(by: [12, 0]).displacement(from: physics.coordinateOrigin)
    state.hitLocal = hit?.point.displacement(from: physics.coordinateOrigin)
    if let marker = state.marker {
        let position = hit?.point ?? state.base.offset(by: [0, 50])
        marker.components[PhysicsPosition2DComponent.self]?.position = position
        marker.components[Transform.self]?.position = Vector3(position.displacement(from: physics.coordinateOrigin), 2)
    }
    let contact = state.crate.flatMap { physics.contacts(for: $0).first }
    state.contactID = contact?.id; state.pointCount = contact?.manifold.points.count ?? 0
    let delta = targetPosition.x - state.base.x - 3
    let grounded = session.character?.components[CharacterController2DComponent.self]?.isGrounded == true
    state.status = String(
        format: "Global hit x %.6f · travel %.3f · target delta %.6f · %d contact points · %@ %@",
        hit?.point.x ?? 0,
        state.distance,
        delta,
        state.pointCount,
        state.mode.rawValue,
        grounded ? "grounded" : "airborne"
    )
}

struct PhysicsLargeWorldDemoPane: View {
    let session: PhysicsDemoSession
    var body: some View {
        let state = session.largeWorld
        VStack(spacing: 10) {
            HStack(spacing: 14) {
                Button("Left") { state.direction = -1 }.accessibilityIdentifier("physics-demo.large-left")
                Button("Stop") { state.direction = 0 }.accessibilityIdentifier("physics-demo.large-stop")
                Button("Right") { state.direction = 1 }.accessibilityIdentifier("physics-demo.large-right")
                Button("Jump") { state.jumpRequested = true }.accessibilityIdentifier("physics-demo.large-jump")
                Button(state.mode == .query ? "Mode: Query" : "Mode: Dynamic") { state.mode = state.mode == .query ? .dynamic : .query }
                    .accessibilityIdentifier("physics-demo.large-mode")
                Button(state.shifted ? "Restore render origin" : "Shift render origin 1 km") { state.shifted.toggle() }
                    .accessibilityIdentifier("physics-demo.large-origin")
                Button("Nudge target 1 mm") { state.nudgeRequested = true }.accessibilityIdentifier("physics-demo.large-nudge")
            }
            Text("Exact physics at 1,000,000,000 units · Camera and tagged roots share the render frame · Yellow probe targets the blue pillar")
                .font(.system(size: 12))
            Text(state.status).font(.system(size: 12))
            SceneView(useSceneCameras: true, make: { configurePhysicsDemo(&$0, session: session) }, updateContent: { _, _ in })
                .frameCaptureLabel("Physics2D Large worlds").id(PhysicsDemoScene.largeWorld)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
