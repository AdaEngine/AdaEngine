import AdaEngine
import Math

@MainActor
func demoHinge(_ direction: Float) -> RevoluteJoint2DSettings {
    .init(frameB: .init(position: [-0.7, 1]), limits: .init(lower: -0.7, upper: 0.7), motor: .init(speed: direction, maximumEffort: 20))
}
@MainActor
func demoSlider(_ direction: Float) -> PrismaticJoint2DSettings {
    .init(spring: .init(hertz: 2), limits: .init(lower: -0.6, upper: 0.6), motor: .init(speed: direction, maximumEffort: 80))
}
@MainActor
func demoWheel(_ direction: Float) -> WheelJoint2DSettings {
    .init(frameA: .init(angle: .pi / 2), limits: .init(lower: -0.8, upper: 0.25), motor: .init(speed: 3 * direction, maximumEffort: 5))
}
@MainActor
func demoMotor(_ direction: Float) -> MotorJoint2DSettings {
    .init(frameA: .init(position: [0.7, 0]), angularVelocity: direction, maximumVelocityForce: 0, maximumVelocityTorque: 3, linearSpring: .init(hertz: 2))
}

@MainActor
func setupMechanisms(in world: World, session: PhysicsDemoSession) throws {
    world.insertResource(PhysicsDebugOptions([.showPhysicsShapes, .showJoints]))
    world.physicsWorld2D?.isSleepEnabled = false
    let positions: [(Vector2, Vector2)] = [
        ([-6, 2.6], [-5, 1.6]), ([0, 2.6], [0.7, 1.6]), ([5, 2.2], [5, 2.2]),
        ([-6, 0.1], [-5, 0.1]), ([0, 0.1], [0, -0.4]), ([5, 0.1], [5, 0.1]),
        ([-6, -2.2], [-6.7, -2.2]), ([0, -2.2], [0, -2.2]), ([5, -2.6], [5, -1.8])
    ]
    for (index, pair) in positions.enumerated() {
        let anchorShape = index == 6 ? Shape2DResource.generateBox(width: 1.2, height: 0.8) : .generateCircle(radius: 0.18)
        var anchorBody = PhysicsBody2DComponent(shapes: [anchorShape], mass: 1, mode: .static)
        anchorBody.debugColor = Color(0.65, 0.7, 0.8, 1)
        let a = world.spawn("Anchor \(index)") { anchorBody; Transform(position: Vector3(pair.0, 0)) }
        let shape: Shape2DResource
        if index == 4 {
            shape = .generateCircle(radius: 0.8)
        } else if index == 8 {
            shape = try .generateCapsule(from: [0, -0.25], to: [0, 0.25], radius: 0.18)
        } else {
            shape = .generateBox(width: 0.45, height: 0.45)
        }
        var body = PhysicsBody2DComponent(shapes: [shape], massProperties: .init(mass: 1, inertia: [0, 0, 0.1]))
        body.debugColor = index == 0 ? Color(1, 0.57, 0.2, 1) : Color(0.3, 0.7, 1, 1)
        if index == 6 { body.gravityScale = 0; body.linearVelocity = [0.5, 0] }
        if index == 3 { body.linearVelocity = [0, 1]; body.angularVelocity = 1 }
        let b = world.spawn("Mechanism body \(index)") { body; Transform(position: Vector3(pair.1, 0)) }
        let descriptor: PhysicsJoint2DDescriptor
        switch index {
        case 0: descriptor = try PhysicsJoint2DDescriptor.rope(entityA: a, entityB: b).withBreakSettings(.init(forceThreshold: 40))
        case 1: descriptor = try .revolute(entityA: a, entityB: b, settings: demoHinge(1))
        case 2: descriptor = try .prismatic(entityA: a, entityB: b, settings: demoSlider(1))
        case 3:
            descriptor = try .weld(
                entityA: a,
                entityB: b,
                settings: .init(frameA: .init(position: [1, 0]), linearSpring: .init(hertz: 2, dampingRatio: 0.3), angularSpring: .init(hertz: 2))
            )
        case 4: descriptor = try .wheel(entityA: a, entityB: b, settings: demoWheel(1))
        case 5: descriptor = try .motor(entityA: a, entityB: b, settings: demoMotor(1))
        case 6: descriptor = try .filter(entityA: a, entityB: b)
        case 7:
            descriptor = try .mover(entityA: a, entityB: b, settings: .init(linearVelocity: [1, 0], maximumVelocityForce: [20, 20], collideConnected: false))
        default: descriptor = try .pogo(entityA: a, entityB: b, settings: .init(restLength: 0.8, maximumCompressionForce: 100))
        }
        session.mechanismOwners.append(world.spawn("Joint \(index)") { PhysicsJoint2DComponent(joint: descriptor) })
        session.targets.append(b)
        session.mechanismStarts.append(pair.1)
    }
}

@MainActor
func controlMechanisms(_ session: PhysicsDemoSession) {
    guard session.targets.count == 9, session.mechanismOwners.count == 9 else {
        return
    }
    if session.resetRequested {
        session.resetRequested = false
        for (index, entity) in session.targets.enumerated() {
            entity.components[PhysicsBody2DComponent.self]?.setPosition(session.mechanismStarts[index], angle: .radians(0))
            entity.components[PhysicsBody2DComponent.self]?.linearVelocity = index == 6 ? [0.5, 0] : .zero
            entity.components[PhysicsBody2DComponent.self]?.angularVelocity = 0
            session.mechanismOwners[index].components[PhysicsJoint2DComponent.self]?.reconnect()
        }
        return
    }
    if session.breakRequested {
        session.breakRequested = false
        session.targets[0].components[PhysicsBody2DComponent.self]?.applyForceToCenter([0, -5000], wake: true)
    }
    do {
        var retuneMover = false
        if session.reverseRequested {
            session.reverseRequested = false; session.driveDirection *= -1; session.moverDirection *= -1
            try session.mechanismOwners[1].components[PhysicsJoint2DComponent.self]?.updateSettings(demoHinge(session.driveDirection))
            try session.mechanismOwners[2].components[PhysicsJoint2DComponent.self]?.updateSettings(demoSlider(session.driveDirection))
            try session.mechanismOwners[4].components[PhysicsJoint2DComponent.self]?.updateSettings(demoWheel(session.driveDirection))
            try session.mechanismOwners[5].components[PhysicsJoint2DComponent.self]?.updateSettings(demoMotor(session.driveDirection))
            retuneMover = true
        }
        let x = session.targets[7].components[Transform.self]?.position.x ?? 0
        if (x > 0.8 && session.moverDirection > 0) || (x < -0.8 && session.moverDirection < 0) { session.moverDirection *= -1; retuneMover = true }
        if retuneMover {
            try session.mechanismOwners[7].components[PhysicsJoint2DComponent.self]?.updateSettings(
                MoverJoint2DSettings(linearVelocity: [session.moverDirection, 0], maximumVelocityForce: [20, 20], collideConnected: false)
            )
        }
    } catch { session.rayStatus = "Tuning failed: \(error)" }
    let filter = session.targets[6]
    let x = filter.components[Transform.self]?.position.x ?? -6
    let velocity = filter.components[PhysicsBody2DComponent.self]?.linearVelocity.x ?? 0.5
    if (x > -5.2 && velocity > 0) || (x < -6.8 && velocity < 0) { filter.components[PhysicsBody2DComponent.self]?.linearVelocity = [-velocity, 0] }
}

struct PhysicsMechanismsDemoPane: View {
    let session: PhysicsDemoSession
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 18) {
                Button("Reverse motors") { session.reverseRequested = true }.accessibilityIdentifier("physics-demo.reverse")
                Button("Break rope") { session.breakRequested = true }.accessibilityIdentifier("physics-demo.break")
                Button("Repair all") { session.resetRequested = true }.accessibilityIdentifier("physics-demo.repair")
            }
            Text("Top: rope / hinge / slider · middle: weld / wheel / motor · bottom: filter / mover / pogo")
            Text(session.rayStatus)
            SceneView(useSceneCameras: true, make: { configurePhysicsDemo(&$0, session: session) }, updateContent: { _, _ in })
                .frameCaptureLabel("Physics2D Mechanisms").id(PhysicsDemoScene.mechanisms)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
