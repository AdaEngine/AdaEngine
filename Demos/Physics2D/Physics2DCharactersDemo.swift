import AdaEngine
import Math

@MainActor
func setupCharacters(in world: World, session: PhysicsDemoSession) throws {
    world.insertResource(PhysicsDebugOptions.showPhysicsShapes)
    world.spawn("Floor") {
        Sprite(tintColor: Color(0.25, 0.35, 0.5, 1), size: [18, 0.4])
        Collision2DComponent(shapes: [.generateBox(width: 18, height: 0.4)])
        Transform(position: [0, -2.2, 0])
    }
    let ramp = try Shape2DResource.generateChain(points: [[7, -1.4], [5, -2], [3, -2]])
    world.spawn("Ramp") { Collision2DComponent(shapes: [ramp]); Transform() }
    world.spawn("Right wall") { Collision2DComponent(shapes: [.generateBox(width: 0.2, height: 4)]); Transform(position: [7.7, -0.2, 0]) }
    session.sensor = world.spawn("Sensor") {
        Sprite(tintColor: Color(0.1, 0.6, 0.4, 0.35), size: [0.5, 2])
        Collision2DComponent(shapes: [.generateBox(width: 0.5, height: 2)], mode: .trigger)
        Transform(position: [-4, -1, -1])
    }
    var controller = CharacterController2DComponent()
    controller.mode = session.characterMode
    session.character = world.spawn("Character") { controller; Transform(position: [-5, 0, 1]) }
    session.crate = world.spawn("Light crate") {
        Sprite(tintColor: Color(1, 0.57, 0.2, 1), size: [0.8, 0.8])
        PhysicsBody2DComponent(shapes: [.generateBox(width: 0.8, height: 0.8)], massProperties: .init(mass: 0.2, inertia: [0, 0, 0.2]))
        Transform(position: [-1, -1.6, 0])
    }
    var platform = PhysicsBody2DComponent(shapes: [.generateBox(width: 3, height: 0.4)], mass: 1, mode: .kinematic)
    platform.linearVelocity = [0.8, 0]
    session.platform = world.spawn("Moving platform") {
        Sprite(tintColor: Color(0.25, 0.6, 1, 1), size: [3, 0.4])
        platform
        Transform(position: [2, -1.3, 0])
    }
}

@MainActor
func controlCharacter(_ session: PhysicsDemoSession) {
    guard let character = session.character else {
        return
    }
    character.components[CharacterController2DComponent.self]?.mode = session.characterMode
    character.components[CharacterController2DComponent.self]?.desiredVelocity = [2.5 * session.moveDirection, 0]
    if session.jumpRequest {
        session.jumpRequest = false
        character.components[CharacterController2DComponent.self]?.jumpRequested = true
    }
    if session.resetRequested {
        session.resetRequested = false; session.moveDirection = 0
        character.components[Transform.self]?.position = [-5, 0, 1]
        character.components[CharacterController2DComponent.self]?.desiredVelocity = .zero
        character.components[CharacterController2DComponent.self]?.resetMotion = true
        session.crate?.components[PhysicsBody2DComponent.self]?.setPosition([-1, -1.6], angle: .radians(0))
        session.crate?.components[PhysicsBody2DComponent.self]?.linearVelocity = .zero
        session.crate?.components[PhysicsBody2DComponent.self]?.angularVelocity = 0
    }
    let x = session.platform?.components[Transform.self]?.position.x ?? 2
    if x > 3.2 { session.platformDirection = -1 }
    if x < 1.2 { session.platformDirection = 1 }
    session.platform?.components[PhysicsBody2DComponent.self]?.linearVelocity = [0.8 * session.platformDirection, 0]
}

@MainActor
func updateCharacterStatus(_ session: PhysicsDemoSession) {
    guard let controller = session.character?.components[CharacterController2DComponent.self] else {
        return
    }
    let velocity = Vector2((controller.velocity.x * 10).rounded() / 10, (controller.velocity.y * 10).rounded() / 10)
    session.rayStatus = "\(controller.mode.rawValue) · \(controller.isGrounded ? "grounded" : "airborne") · velocity \(velocity.x), \(velocity.y)"
}

struct PhysicsCharactersDemoPane: View {
    let session: PhysicsDemoSession
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                Button("Left") { session.moveDirection = -1 }.accessibilityIdentifier("physics-demo.left")
                Button("Stop") { session.moveDirection = 0 }.accessibilityIdentifier("physics-demo.stop")
                Button("Right") { session.moveDirection = 1 }.accessibilityIdentifier("physics-demo.right")
                Button("Jump") { session.jumpRequest = true }.accessibilityIdentifier("physics-demo.jump")
                Button(session.characterMode == .query ? "Mode: Query" : "Mode: Dynamic") { session.characterMode = session.characterMode == .query ? .dynamic : .query }
                    .accessibilityIdentifier("physics-demo.character-mode")
                Button("Reset") { session.resetRequested = true }.accessibilityIdentifier("physics-demo.character-reset")
            }
            Text("Move and jump onto the moving platform. Dynamic mode pushes the orange crate; query mode is virtual.")
            Text(session.rayStatus)
            SceneView(useSceneCameras: true, make: { configurePhysicsDemo(&$0, session: session) }, updateContent: { _, _ in })
                .frameCaptureLabel("Physics2D Characters").id(PhysicsDemoScene.characters)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
