//
//  SceneViewExample.swift
//  AdaEngine
//
//  Created by Codex on 24.05.2026.
//

import AdaEngine

@main
struct SceneViewExampleApp: App {
    var body: some AppScene {
        WindowGroup {
            SceneViewDemo()
        }
        .windowMode(.windowed)
        .windowTitle("SceneView Example")
    }
}

private struct SceneViewDemo: View {

    @State private var dragStartCameraOffset: Vector2 = .zero
    @State private var cameraDragOffset: Vector2 = .zero

    var body: some View {
        ZStack(anchor: .topLeading) {
            SceneView(
                pluginPreset: .mesh2D,
                setup: { world in
                    SceneViewDemoWorld.setup(world)
                },
                update: { world, deltaTime in
                    SceneViewDemoWorld.update(
                        world,
                        deltaTime: deltaTime,
                        cameraDragOffset: cameraDragOffset
                    )
                },
                content: { context in
                    context.viewport
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    cameraDragOffset = dragStartCameraOffset + Vector2(
                                        -value.translation.width,
                                        value.translation.height
                                    )
                                }
                                .onEnded { value in
                                    cameraDragOffset = dragStartCameraOffset + Vector2(
                                        -value.translation.width,
                                        value.translation.height
                                    )
                                    dragStartCameraOffset = cameraDragOffset
                                }
                        )
                }
            )
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)

            SceneViewOverlay()
        }
    }
}

private struct SceneViewOverlay: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SceneView")
                .fontSize(16)
                .foregroundColor(.white)

            Text("Camera + ECS entities")
                .fontSize(12)
                .foregroundColor(Color.white.opacity(0.72))
        }
        .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
        .background(Color.fromHex(0x171A1F).opacity(0.88))
        .border(Color.white.opacity(0.14), lineWidth: 1)
        .padding(16)
    }
}

private enum SceneViewDemoWorld {

    static func setup(_ world: World) {
        world.insertResource(SceneViewDemoState())
        configureCamera(in: world)
        spawnGrid(in: world)
        spawnControlledEntity(in: world)
        spawnMovingEntities(in: world)
    }

    static func update(
        _ world: World,
        deltaTime: TimeInterval,
        cameraDragOffset: Vector2
    ) {
        guard var state = world.getResource(SceneViewDemoState.self) else {
            return
        }

        state.elapsed += deltaTime

        if let input = world.getResource(Input.self) {
            updateCameraState(&state, input: input, deltaTime: deltaTime)
            updateControlledEntityState(&state, input: input, deltaTime: deltaTime)
        }

        updateEntities(in: world, state: state)
        updateCamera(in: world, state: state, dragOffset: cameraDragOffset)
        world.insertResource(state)
    }

    private static func configureCamera(in world: World) {
        for entity in world.getEntities() {
            guard var camera = entity.components[Camera.self] else {
                continue
            }

            camera.backgroundColor = Color.fromHex(0x0E1116)
            camera.clearFlags = .solid
            entity.components += camera
        }
    }

    private static func spawnGrid(in world: World) {
        let whiteTexture = Texture2D.whiteTexture

        world.spawn("SceneView_Background") {
            Sprite(
                texture: whiteTexture,
                tintColor: Color.fromHex(0x111820),
                size: Size(width: 2400, height: 1600)
            )
            Transform(position: Vector3(0, 0, -20))
        }

        for index in -12...12 {
            let offset = Float(index * 100)
            let tintColor = index == 0
                ? Color.fromHex(0x52606E)
                : Color.fromHex(0x26313D)

            world.spawn("SceneView_GridVertical") {
                Sprite(
                    texture: whiteTexture,
                    tintColor: tintColor,
                    size: Size(width: index == 0 ? 4 : 2, height: 1600)
                )
                Transform(position: Vector3(offset, 0, -10))
            }

            world.spawn("SceneView_GridHorizontal") {
                Sprite(
                    texture: whiteTexture,
                    tintColor: tintColor,
                    size: Size(width: 2400, height: index == 0 ? 4 : 2)
                )
                Transform(position: Vector3(0, offset, -10))
            }
        }
    }

    private static func spawnControlledEntity(in world: World) {
        world.spawn("SceneView_ControlledEntity") {
            SceneViewControlledEntity()
            Sprite(
                texture: Texture2D.whiteTexture,
                tintColor: Color.fromHex(0x2D7EFF),
                size: Size(width: 84, height: 84)
            )
            Transform(position: Vector3(0, 0, 2))
        }
    }

    private static func spawnMovingEntities(in world: World) {
        let entities: [(Vector3, Vector2, Float, Float, Color, Size)] = [
            (Vector3(-360, -160, 1), Vector2(130, 70), 0.0, 0.9, Color.fromHex(0xF59E0B), Size(width: 70, height: 70)),
            (Vector3(280, -220, 1), Vector2(90, 140), 1.7, 1.15, Color.fromHex(0x10B981), Size(width: 110, height: 58)),
            (Vector3(-120, 220, 1), Vector2(180, 50), 3.2, 0.7, Color.fromHex(0xF43F5E), Size(width: 58, height: 110)),
            (Vector3(360, 180, 1), Vector2(80, 90), 4.4, 1.35, Color.fromHex(0xA78BFA), Size(width: 76, height: 76)),
        ]

        for (origin, radius, phase, speed, color, size) in entities {
            world.spawn("SceneView_MovingEntity") {
                SceneViewMovingEntity(
                    origin: origin,
                    radius: radius,
                    phase: phase,
                    speed: speed
                )
                Sprite(
                    texture: Texture2D.whiteTexture,
                    tintColor: color,
                    size: size
                )
                Transform(position: origin)
            }
        }
    }

    private static func updateCameraState(
        _ state: inout SceneViewDemoState,
        input: Input,
        deltaTime: TimeInterval
    ) {
        var direction = Vector2.zero

        if input.isKeyPressed(.a) { direction.x -= 1 }
        if input.isKeyPressed(.d) { direction.x += 1 }
        if input.isKeyPressed(.w) { direction.y += 1 }
        if input.isKeyPressed(.s) { direction.y -= 1 }

        if direction != .zero {
            state.cameraPosition += direction.normalized * 380 * deltaTime
        }

        if input.isKeyPressed(.q) {
            state.cameraScale = min(state.cameraScale + 0.9 * deltaTime, 2.2)
        }

        if input.isKeyPressed(.e) {
            state.cameraScale = max(state.cameraScale - 0.9 * deltaTime, 0.45)
        }
    }

    private static func updateControlledEntityState(
        _ state: inout SceneViewDemoState,
        input: Input,
        deltaTime: TimeInterval
    ) {
        var direction = Vector2.zero

        if input.isKeyPressed(.arrowLeft) { direction.x -= 1 }
        if input.isKeyPressed(.arrowRight) { direction.x += 1 }
        if input.isKeyPressed(.arrowUp) { direction.y += 1 }
        if input.isKeyPressed(.arrowDown) { direction.y -= 1 }

        if direction != .zero {
            let speed: Float = input.isKeyPressed(.space) ? 520 : 260
            state.controlledEntityPosition += direction.normalized * speed * deltaTime
        }
    }

    private static func updateEntities(
        in world: World,
        state: SceneViewDemoState
    ) {
        for entity in world.getEntities() {
            if entity.components[SceneViewControlledEntity.self] != nil,
               var transform = entity.components[Transform.self] {
                transform.position.x = state.controlledEntityPosition.x
                transform.position.y = state.controlledEntityPosition.y
                transform.rotation = Quat(axis: Vector3(0, 0, 1), angle: state.elapsed * 0.8)
                entity.components += transform
                continue
            }

            guard let moving = entity.components[SceneViewMovingEntity.self],
                  var transform = entity.components[Transform.self] else {
                continue
            }

            let time = state.elapsed * moving.speed + moving.phase
            transform.position.x = moving.origin.x + Math.cos(time) * moving.radius.x
            transform.position.y = moving.origin.y + Math.sin(time * 1.2) * moving.radius.y
            transform.rotation = Quat(axis: Vector3(0, 0, 1), angle: time)
            entity.components += transform
        }
    }

    private static func updateCamera(
        in world: World,
        state: SceneViewDemoState,
        dragOffset: Vector2
    ) {
        for entity in world.getEntities() {
            guard var camera = entity.components[Camera.self],
                  var transform = entity.components[Transform.self] else {
                continue
            }

            let position = state.cameraPosition + dragOffset
            transform.position.x = position.x
            transform.position.y = position.y

            if case .orthographic(var projection) = camera.projection {
                projection.scale = state.cameraScale
                camera.projection = .orthographic(projection)
            }

            entity.components += camera
            entity.components += transform
        }
    }
}

private struct SceneViewDemoState: Resource {
    var elapsed: TimeInterval = 0
    var cameraPosition: Vector2 = .zero
    var cameraScale: Float = 1
    var controlledEntityPosition: Vector2 = .zero
}

@Component
private struct SceneViewControlledEntity {}

@Component
private struct SceneViewMovingEntity {
    var origin: Vector3
    var radius: Vector2
    var phase: Float
    var speed: Float
}
