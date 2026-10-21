import AdaEngine
import Foundation
import Math
import Observation

@MainActor
@Observable
final class PhysicsAdvancedState {
    var windMode = 0
    var reverseBelt = false
    var rolling = true
    var lowGrip = false
    var damping = false
    var bullet = true
    var locked = false
    var softSolver = false
    var dirty = true
    var sleepRequested = false
    var resetRequested = false
    var refireRequested = false
    var belt: Entity?
    var box: Entity?
    var circle: Entity?
    var air: Entity?
    var projectile: Entity?
    var markers: [Entity] = []
    var defaults: PhysicsSolver2DSettings?
    var pointCount = 0
    var hitPoints = 0
    var status = "Waiting for contacts"
}

@MainActor
func setupAdvanced(in world: World, session: PhysicsDemoSession) throws {
    let state = session.advanced
    state.defaults = world.physicsWorld2D?.solverSettings
    world.insertResource(PhysicsDebugOptions([.showPhysicsShapes]))
    let beltMaterial = try PhysicsMaterial.generate2D(surfaceSpeed: 1.8)
    state.belt = world.spawn("Conveyor") {
        Collision2DComponent(shapes: [.generateBox(width: 17, height: 0.4)], material: beltMaterial)
        Sprite(tintColor: Color(0.24, 0.35, 0.5, 1), size: [17, 0.4])
        Transform(position: [0, -3.3, 0])
    }
    for x: Float in [-8.5, 8.5] {
        world.spawn("Boundary") { Collision2DComponent(shapes: [.generateBox(width: 0.25, height: 8)]); Transform(position: [x, 0, 0]) }
    }
    state.box = world.spawn("Conveyor box") {
        PhysicsBody2DComponent(shapes: [.generateBox(width: 0.8, height: 0.8)], mass: 1)
        Sprite(tintColor: Color(1, 0.65, 0.25, 1), size: [0.8, 0.8])
        Transform(position: [-3, -2.7, 0])
    }
    var circle = PhysicsBody2DComponent(shapes: [.generateCircle(radius: 1.2)], mass: 1)
    circle.debugColor = Color(0.3, 1, 0.5, 1)
    circle.linearVelocity = [2, 0]; circle.angularVelocity = -2 / 0.6
    state.circle = world.spawn("Rolling circle") { circle; Transform(position: [-6, -2.5, 0]) }
    let capsule = try Shape2DResource.generateCapsule(from: [0, -0.35], to: [0, 0.35], radius: 0.25)
    var air = PhysicsBody2DComponent(shapes: [capsule], mass: 2)
    air.gravityScale = 0; air.debugColor = Color(0.2, 0.85, 1, 1)
    state.air = world.spawn("Wind capsule") { air; PhysicsWind2DComponent(.init(drag: 0)); Transform(position: [0, 0.7, 0]) }
    world.spawn("Thin kinematic CCD target") {
        PhysicsBody2DComponent(shapes: [.generateBox(width: 0.04, height: 1.5)], mode: .kinematic)
        Sprite(tintColor: .white, size: [0.04, 1.5])
        Transform(position: [0, 2.5, 0])
    }
    var projectile = PhysicsBody2DComponent(shapes: [.generateBox(width: 0.2, height: 0.2)], mass: 1)
    projectile.gravityScale = 0; projectile.fixedRotation = true
    state.projectile = world.spawn("CCD box") {
        projectile
        Sprite(tintColor: Color(1, 0.3, 0.3, 1), size: [0.2, 0.2])
        Transform(position: [-6, 2.5, 0])
    }
    state.refireRequested = true
    for _ in 0..<4 {
        state.markers.append(world.spawn("Contact point") { Sprite(tintColor: Color(1, 0.2, 0.55, 1), size: [0.1, 0.1]); Transform(position: [0, 50, 3]) })
    }
}

@MainActor
func controlAdvanced(in world: World, session: PhysicsDemoSession) {
    let state = session.advanced
    do {
        if state.dirty {
            if let belt = state.belt, belt.components[Collision2DComponent.self]?.material.surfaceSpeed != (state.reverseBelt ? -1.8 : 1.8) {
                belt.components[Collision2DComponent.self]?.material = try .generate2D(surfaceSpeed: state.reverseBelt ? -1.8 : 1.8)
            }
            var mixing = PhysicsMaterialMixing()
            mixing.friction = state.lowGrip ? .minimum : .maximum; mixing.priority = 10
            let friction: Float = state.lowGrip ? 0.05 : 0.8
            let rolling: Float = state.rolling ? 0.2 : 0
            if let circle = state.circle, let current = circle.components[PhysicsBody2DComponent.self]?.material,
                current.friction != friction || current.rollingResistance != rolling || current.mixing != mixing {
                circle.components[PhysicsBody2DComponent.self]?.material = try .generate2D(friction: friction, rollingResistance: rolling, mixing: mixing)
            }
            var dynamics = PhysicsBody2DDynamics()
            dynamics.linearDamping = state.damping ? 2 : 0; dynamics.angularDamping = state.damping ? 3 : 0
            try state.air?.components[PhysicsBody2DComponent.self]?.configureDynamics(dynamics)
            var motion = PhysicsBody2DMotion()
            motion.lockTranslationX = state.locked; motion.lockTranslationY = state.locked; motion.lockRotation = state.locked
            try state.air?.components[PhysicsBody2DComponent.self]?.configureMotion(motion)
            state.air?.components[PhysicsWind2DComponent.self]?.settings = .init(velocity: state.windMode == 1 ? [6, 0] : .zero, drag: state.windMode == 0 ? 0 : 1)
            if state.windMode == 1 { state.air?.components[PhysicsBody2DComponent.self]?.setAwake(true) }
            dynamics = .init(); dynamics.isBullet = state.bullet; dynamics.safetyFactor = 0.01
            try state.projectile?.components[PhysicsBody2DComponent.self]?.configureDynamics(dynamics)
            if var solver = state.defaults {
                if state.softSolver {
                    solver.contactHertz = 8; solver.contactDampingRatio = 1; solver.contactPushSpeed = 1
                    solver.restitutionIterations = 8; solver.isRestitutionPropagationEnabled = true
                }
                try world.physicsWorld2D?.configureSolver(solver)
            }
            state.dirty = false
        }
        if state.resetRequested {
            state.box?.components[PhysicsBody2DComponent.self]?.setPosition([-3, -2.7])
            state.box?.components[PhysicsBody2DComponent.self]?.clearForces()
            state.circle?.components[PhysicsBody2DComponent.self]?.setPosition([-6, -2.5])
            state.circle?.components[PhysicsBody2DComponent.self]?.linearVelocity = [2, 0]
            state.circle?.components[PhysicsBody2DComponent.self]?.angularVelocity = -2 / 0.6
            state.air?.components[PhysicsBody2DComponent.self]?.setPosition([0, 0.7])
            state.air?.components[PhysicsBody2DComponent.self]?.clearForces()
            state.air?.components[PhysicsBody2DComponent.self]?.setAwake(true)
            state.refireRequested = true; state.resetRequested = false
        }
        if state.refireRequested {
            state.projectile?.components[PhysicsBody2DComponent.self]?.setPosition([-6, 2.5])
            state.projectile?.components[PhysicsBody2DComponent.self]?.linearVelocity = [50, 0]
            state.refireRequested = false
        }
        if state.sleepRequested {
            if let entity = state.air, let body = entity.components[PhysicsBody2DComponent.self] { entity.components[PhysicsBody2DComponent.self]?.setAwake(!body.isAwake) }
            state.sleepRequested = false
        }
    } catch { state.status = "Control failed: \(error)" }
}

@MainActor
func frameAdvanced(in world: World, session: PhysicsDemoSession) {
    let state = session.advanced
    guard let physics = world.physicsWorld2D, let box = state.box else {
        return
    }
    let contacts = physics.contacts(for: box)
    let points = contacts.flatMap { $0.manifold.points }
    state.pointCount = points.count
    let impulse = points.reduce(Float(0)) { $0 + $1.totalNormalImpulse }
    let separation = points.first?.separation ?? 0
    let identifier = contacts.first.map { String(UInt(bitPattern: $0.id.hashValue), radix: 16).suffix(6) } ?? "none"
    let velocity = state.air?.components[PhysicsBody2DComponent.self]?.linearVelocity.x ?? 0
    let awake = state.air?.components[PhysicsBody2DComponent.self]?.isAwake == true
    state.status = String(
        format: "Contact #%@ · %d points · separation %.3f · impulse %.3f · wind vx %.2f · %@ · hit points %d",
        String(identifier),
        points.count,
        separation,
        impulse,
        velocity,
        awake ? "awake" : "sleeping",
        state.hitPoints
    )
    for (index, marker) in state.markers.enumerated() {
        marker.components[Transform.self]?.position = index < points.count ? Vector3(points[index].point, 3) : [0, 50, 3]
    }
}

struct PhysicsAdvancedDemoPane: View {
    let session: PhysicsDemoSession
    var body: some View {
        let state = session.advanced
        VStack(spacing: 8) {
            HStack(spacing: 14) {
                Button(["Wind: off", "Wind: airflow", "Wind: still-air drag"][state.windMode]) { state.windMode = (state.windMode + 1) % 3; state.dirty = true }
                    .accessibilityIdentifier("physics-demo.advanced-wind")
                Button(state.reverseBelt ? "Belt: left" : "Belt: right") { state.reverseBelt.toggle(); state.dirty = true }
                    .accessibilityIdentifier("physics-demo.advanced-belt")
                Button(state.rolling ? "Rolling resistance: on" : "Rolling resistance: off") { state.rolling.toggle(); state.dirty = true }
                    .accessibilityIdentifier("physics-demo.advanced-rolling")
                Button(state.lowGrip ? "Mixing: minimum grip" : "Mixing: maximum grip") { state.lowGrip.toggle(); state.dirty = true }
                    .accessibilityIdentifier("physics-demo.advanced-grip")
            }
            HStack(spacing: 14) {
                Button(state.damping ? "Damping: high" : "Damping: off") { state.damping.toggle(); state.dirty = true }
                    .accessibilityIdentifier("physics-demo.advanced-damping")
                Button(state.bullet ? "CCD bullet: on" : "CCD bullet: off") { state.bullet.toggle(); state.dirty = true; state.refireRequested = true }
                    .accessibilityIdentifier("physics-demo.advanced-bullet")
                Button(state.locked ? "Axes: locked" : "Axes: free") { state.locked.toggle(); state.dirty = true }
                    .accessibilityIdentifier("physics-demo.advanced-lock")
                Button("Sleep / wake capsule") { state.sleepRequested = true }
                    .accessibilityIdentifier("physics-demo.advanced-sleep")
                Button(state.softSolver ? "Solver: soft / 8 restitution" : "Solver: default") { state.softSolver.toggle(); state.dirty = true }
                    .accessibilityIdentifier("physics-demo.advanced-solver")
                Button("Reset") { state.resetRequested = true }
                    .accessibilityIdentifier("physics-demo.advanced-reset")
            }
            Text("Green: rolling + grip mixing · Cyan: wind + damping · Red: fast box vs thin kinematic wall · Pink: contact points")
            Text(state.status).font(.system(size: 12))
            SceneView(useSceneCameras: true, make: { configurePhysicsDemo(&$0, session: session) }, updateContent: { _, _ in })
                .frameCaptureLabel("Physics2D Advanced").id(PhysicsDemoScene.advanced)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
