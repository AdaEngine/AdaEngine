//
//  ThrowingShapes2DExample.swift
//  AdaEngine
//

import AdaEngine
import Foundation

@main
struct ThrowingShapes2DExample: App {
    var body: some AppScene {
        GameAppScene {
            Scene(from: World())
        }
        .addPlugins(
            DefaultPlugins()
                .set(Physics2DPlugin(gravity: [0, -900]))
                .set(ThrowingShapes2DPlugin())
        )
        .windowMode(.windowed)
        .minimumSize(width: 1_440, height: 1_000)
        .transformAppWorlds { appWorlds in
            appWorlds.main.getRefResource(WindowSettings.self).wrappedValue.frame = Rect(
                origin: .zero,
                size: Size(width: 1_440, height: 1_000)
            )
        }
        .windowTitle("Throwing Shapes 2D")
    }
}

private struct ThrowingShapes2DPlugin: Plugin {
    func setup(in app: AppWorlds) {
        app.insertResource(ThrowingShapesResources())
        app.addSystem(ThrowingShapesSetupSystem.self, on: .startup)
        app.addSystem(ThrowingShapesInputSystem.self)
    }
}

private struct ThrowingShapesResources: Resource {
    let ballTexture = Texture2D(image: Self.makeBallImage())
    let squareShape = Shape2DResource.generateBox(width: 52, height: 52)
    let ballShape = Shape2DResource.generateCircle(radius: 44)
    let material = PhysicsMaterial.generate(friction: 0.48, restitution: 0.38, density: 1)

    private static func makeBallImage() -> Image {
        let diameter = 96
        let radius = Float(diameter) / 2
        var image = Image(width: diameter, height: diameter)

        for y in 0..<diameter {
            for x in 0..<diameter {
                let deltaX = Float(x) + 0.5 - radius
                let deltaY = Float(y) + 0.5 - radius
                let distance = (deltaX * deltaX + deltaY * deltaY).squareRoot()
                let alpha = max(0, min(1, radius - distance + 1))
                image.setPixel(
                    in: Point(x: Float(x), y: Float(y)),
                    color: Color(red: 1, green: 1, blue: 1, alpha: alpha)
                )
            }
        }

        return image
    }
}

@Component
struct DraggableShape {
    let pickingRadius: Float
}

@System
func ThrowingShapesSetup(
    _ commands: Commands
) {
    var camera = Camera()
    camera.backgroundColor = Color.fromHex(0x111827)

    commands.spawn("Camera", bundle: Camera2D(camera: camera))
    spawnRectangle(
        named: "Floor",
        at: [0, -450],
        size: [1_380, 34],
        color: Color.fromHex(0x334155),
        commands: commands
    )
    spawnRectangle(
        named: "Left wall",
        at: [-675, -20],
        size: [30, 900],
        color: Color.fromHex(0x334155),
        commands: commands
    )
    spawnRectangle(
        named: "Right wall",
        at: [675, -20],
        size: [30, 900],
        color: Color.fromHex(0x334155),
        commands: commands
    )
    spawnRectangle(
        named: "Center platform",
        at: [180, -145],
        size: [280, 24],
        color: Color.fromHex(0x475569),
        commands: commands
    )
    commands.spawn("Instructions", bundle: makeInstructions())
}

private func spawnRectangle(
    named name: String,
    at position: Vector2,
    size: Vector2,
    color: Color,
    commands: Commands
) {
    commands.spawn(name) {
        Sprite(
            texture: Texture2D.whiteTexture,
            tintColor: color,
            size: Size(width: size.x, height: size.y)
        )
        PhysicsBody2DComponent(
            shapes: [Shape2DResource.generateBox(width: size.x, height: size.y)],
            mode: .static
        )
        Transform(position: [position.x, position.y, 0])
    }
}

private func makeInstructions() -> Text2D {
    var attributes = TextAttributeContainer()
    attributes.foregroundColor = Color.fromHex(0xE2E8F0)
    attributes.font = .system(size: 22)

    return Text2D(
        textComponent: TextComponent(
            text: AttributedText("LBM — catch and throws  RBM — spawn circle   Space — spawn rect", attributes: attributes)
        ),
        transform: Transform(position: [0, 420, 0])
    )
}

@PlainSystem
struct ThrowingShapesInputSystem {
    private let maximumThrowSpeed: Float = 1_250

    @Query<Camera, GlobalTransform>
    private var cameras

    @Res<ThrowingShapesResources>
    private var resources

    @Res<Input>
    private var input

    @Res<DeltaTime>
    private var deltaTime

    @Query<Entity, Ref<Transform>, Ref<PhysicsBody2DComponent>, DraggableShape>
    private var draggableShapes

    @Commands
    private var commands

    @Local
    private var wasLeftMousePressed = false

    @Local
    private var wasRightMousePressed = false

    @Local
    private var wasSpacePressed = false

    @Local
    private var grabbedEntityID: Entity.ID?

    @Local
    private var previousCursorPosition: Vector2?

    @Local
    private var grabVelocity: Vector2 = .zero

    init(world: World) {}

    func update(context: UpdateContext) {
        let isLeftMousePressed = input.isMouseButtonPressed(.left)
        let isRightMousePressed = input.isMouseButtonPressed(.right)
        let isSpacePressed = input.isKeyPressed(.space)
        defer {
            wasLeftMousePressed = isLeftMousePressed
            wasRightMousePressed = isRightMousePressed
            wasSpacePressed = isSpacePressed
        }

        guard let cursorPosition = cursorWorldPosition() else {
            return
        }

        if isLeftMousePressed && !wasLeftMousePressed {
            beginGrab(at: cursorPosition)
        }
        if isLeftMousePressed {
            moveGrabbedShape(to: cursorPosition)
        }
        if !isLeftMousePressed && wasLeftMousePressed {
            releaseGrab()
        }
        if isSpacePressed && !wasSpacePressed {
            spawnSquare(at: cursorPosition)
        }
        if isRightMousePressed && !wasRightMousePressed {
            spawnBall(at: cursorPosition)
        }
    }

    private func cursorWorldPosition() -> Vector2? {
        var result: Vector2?
        let mousePosition = input.getMousePosition()

        cameras.forEach { camera, globalTransform in
            guard result == nil else {
                return
            }
            result = camera.viewportToWorld2D(
                cameraGlobalTransform: globalTransform.matrix,
                viewportPosition: mousePosition
            ).map { Vector2($0.x, -$0.y) }
        }

        return result
    }

    private func spawnBall(at position: Vector2) {
        commands.spawn("Ball") {
            Sprite(
                texture: resources.ballTexture,
                tintColor: Color.fromHex(0xFACC15),
                size: Size(width: 44, height: 44)
            )
            PhysicsBody2DComponent(
                shapes: [resources.ballShape],
                mass: 1,
                material: resources.material,
                mode: .dynamic
            )
            DraggableShape(pickingRadius: 28)
            Transform(position: [position.x, position.y, 0])
        }
    }

    private func spawnSquare(at position: Vector2) {
        commands.spawn("Square") {
            Sprite(
                texture: Texture2D.whiteTexture,
                tintColor: Color.fromHex(0xA78BFA),
                size: Size(width: 52, height: 52)
            )
            PhysicsBody2DComponent(
                shapes: [resources.squareShape],
                mass: 1,
                material: resources.material,
                mode: .dynamic
            )
            DraggableShape(pickingRadius: 38)
            Transform(position: [position.x, position.y, 0])
        }
    }

    private func beginGrab(at position: Vector2) {
        var closestEntityID: Entity.ID?
        var closestDistanceSquared = Float.greatestFiniteMagnitude

        draggableShapes.forEach { entity, transform, physicsBody, draggable in
            guard case .dynamic = physicsBody.mode else {
                return
            }

            let offset = transform.position.xy - position
            let distanceSquared = offset.squaredLength
            guard distanceSquared <= draggable.pickingRadius * draggable.pickingRadius,
                  distanceSquared < closestDistanceSquared else {
                return
            }

            closestEntityID = entity.id
            closestDistanceSquared = distanceSquared
        }

        grabbedEntityID = closestEntityID
        previousCursorPosition = closestEntityID == nil ? nil : position
        grabVelocity = .zero
    }

    private func moveGrabbedShape(to position: Vector2) {
        guard let grabbedEntityID else {
            return
        }

        var wasFound = false
        draggableShapes.forEach { entity, _, physicsBody, _ in
            guard entity.id == grabbedEntityID else {
                return
            }

            wasFound = true
            physicsBody.gravityScale = 0
            physicsBody.linearVelocity = .zero
            physicsBody.angularVelocity = 0
            physicsBody.wrappedValue.setPosition(position)
        }

        guard wasFound else {
            clearGrabState()
            return
        }

        if let previousCursorPosition, deltaTime.deltaTime > 0 {
            let instantaneousVelocity = (position - previousCursorPosition) / Float(deltaTime.deltaTime)
            grabVelocity = grabVelocity * 0.65 + instantaneousVelocity * 0.35
        }
        previousCursorPosition = position
    }

    private func releaseGrab() {
        guard let grabbedEntityID else {
            return
        }

        draggableShapes.forEach { entity, _, physicsBody, _ in
            guard entity.id == grabbedEntityID else {
                return
            }

            physicsBody.gravityScale = 1
            physicsBody.linearVelocity = clamped(grabVelocity, maximumLength: maximumThrowSpeed)
        }

        clearGrabState()
    }

    private func clearGrabState() {
        grabbedEntityID = nil
        previousCursorPosition = nil
        grabVelocity = .zero
    }

    private func clamped(_ vector: Vector2, maximumLength: Float) -> Vector2 {
        guard vector.squaredLength > maximumLength * maximumLength else {
            return vector
        }

        return vector.normalized * maximumLength
    }
}
