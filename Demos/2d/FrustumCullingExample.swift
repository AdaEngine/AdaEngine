//
//  FrustumCullingExample.swift
//  AdaEngine
//
//  Created by Codex on 19.06.2026.
//

import AdaEngine

private let sweepDistance: Float = 2600
private let markerSpacing: Float = 500

@main
struct FrustumCullingExample: App {
    var body: some AppScene {
        DefaultAppWindow()
            .addPlugins(
                FrustumCullingExamplePlugin()
            )
            .windowMode(.windowed)
            .windowTitle("Frustum Culling Example")
    }
}

struct FrustumCullingExamplePlugin: Plugin {
    func setup(in app: borrowing AppWorlds) {
        app.main.addSystem(SetupFrustumCullingDemoSystem.self, on: .startup)
        app.main.addSystem(SweepCameraSystem.self)
        app.main.addSystem(UpdateCullingHUDSystem.self)
        app.main.addSystem(PrintCullingStatsSystem.self)
    }
}

@Component
struct SweepCamera {}

@Component
struct CullingHUD {}

@Component
struct CullingStatsTimer {
    var elapsed: TimeInterval = 0
}

@PlainSystem
struct SetupFrustumCullingDemoSystem {
    init(world: World) { }

    func update(context: UpdateContext) {
        var camera = Camera()
        camera.backgroundColor = Color(red: 0.07, green: 0.08, blue: 0.11, alpha: 1)
        camera.clearFlags = .solid

        context.world.spawn("Frustum Sweep Camera", bundle: Camera2D(
            camera: camera,
            orthographicProjection: OrthographicProjection(scale: 1.25),
            transform: Transform(position: Vector3(0, 0, 0))
        ).extend {
            SweepCamera()
        })

        spawnMarkerLine(in: context.world)
        spawnSpriteField(in: context.world)
        spawnHUD(in: context.world)

        context.world.spawn("Culling Stats Timer") {
            CullingStatsTimer()
        }
    }

    private func spawnSpriteField(in world: World) {
        let colors: [Color] = [
            Color(red: 0.23, green: 0.56, blue: 1.0, alpha: 1),
            Color(red: 0.24, green: 0.86, blue: 0.56, alpha: 1),
            Color(red: 1.0, green: 0.76, blue: 0.20, alpha: 1),
            Color(red: 1.0, green: 0.34, blue: 0.44, alpha: 1),
        ]

        let texture = Texture2D.whiteTexture
        var colorIndex = 0

        for x in stride(from: -3000, through: 3000, by: 120) {
            for y in stride(from: -260, through: 260, by: 130) {
                let tint = colors[colorIndex % colors.count]
                colorIndex += 1

                world.spawn("Cullable Sprite") {
                    Transform(position: Vector3(Float(x), Float(y), 0))
                    Sprite(
                        texture: texture,
                        tintColor: tint,
                        size: Size(width: 84, height: 84)
                    )
                }
            }
        }
    }

    private func spawnMarkerLine(in world: World) {
        let texture = Texture2D.whiteTexture

        world.spawn("Origin Marker") {
            Transform(position: Vector3(0, 0, -0.1))
            Sprite(
                texture: texture,
                tintColor: Color(red: 1, green: 1, blue: 1, alpha: 0.9),
                size: Size(width: 16, height: 720)
            )
        }

        for x in stride(from: Float(-2500), through: Float(2500), by: markerSpacing) where x != 0 {
            let isFarMarker = abs(x).truncatingRemainder(dividingBy: 1000) == 0
            world.spawn("Distance Marker") {
                Transform(position: Vector3(x, 0, -0.1))
                Sprite(
                    texture: texture,
                    tintColor: isFarMarker
                        ? Color(red: 1.0, green: 0.45, blue: 0.2, alpha: 0.7)
                        : Color(red: 0.6, green: 0.68, blue: 0.78, alpha: 0.45),
                    size: Size(width: isFarMarker ? 12 : 6, height: isFarMarker ? 620 : 420)
                )
            }

            spawnLabel(
                "x=\(Int(x))",
                in: world,
                position: Vector3(x, -340, 0.2),
                color: .white,
                size: 28
            )
        }

        spawnLabel(
            "origin",
            in: world,
            position: Vector3(0, -340, 0.2),
            color: .white,
            size: 32
        )
    }

    private func spawnHUD(in world: World) {
        let entity = spawnLabel(
            "Frustum Culling Demo",
            in: world,
            position: Vector3(-520, 320, 1),
            color: Color(red: 0.88, green: 0.94, blue: 1.0, alpha: 1),
            size: 30
        )
        entity.components += CullingHUD()
    }

    @discardableResult
    private func spawnLabel(
        _ text: String,
        in world: World,
        position: Vector3,
        color: Color,
        size: Float
    ) -> Entity {
        var attributes = TextAttributeContainer()
        attributes.foregroundColor = color
        attributes.font = .system(size: Double(size))

        return world.spawn(
            "Label",
            bundle: Text2D(
                textComponent: TextComponent(text: AttributedText(text, attributes: attributes)),
                transform: Transform(position: position)
            )
        )
    }
}

@PlainSystem
struct SweepCameraSystem {
    @FilterQuery<Ref<Transform>, With<SweepCamera>>
    private var cameras

    @Res<ElapsedTime>
    private var time

    init(world: World) { }

    func update(context: UpdateContext) {
        cameras.forEach { transform in
            transform.position.x = Math.sin(time.elapsedTime * 0.35) * sweepDistance
            transform.position.y = Math.sin(time.elapsedTime * 0.7) * 80
        }
    }
}

@PlainSystem
struct UpdateCullingHUDSystem {
    @FilterQuery<Transform, VisibleEntities, With<SweepCamera>>
    private var cameras

    @FilterQuery<Ref<Transform>, Ref<TextComponent>, With<CullingHUD>>
    private var huds

    init(world: World) { }

    func update(context: UpdateContext) {
        guard let camera = cameras.first else {
            return
        }

        let cameraTransform = camera.0
        let visibleEntities = camera.1
        let message = """
        Frustum Culling Demo
        camera x: \(Int(cameraTransform.position.x))
        visible entities: \(visibleEntities.entityIds.count)
        """

        huds.forEach { transform, text in
            transform.position = cameraTransform.position + Vector3(-500, 300, 1)

            var attributes = TextAttributeContainer()
            attributes.foregroundColor = Color(red: 0.88, green: 0.94, blue: 1.0, alpha: 1)
            attributes.font = .system(size: 30)
            text.text = AttributedText(message, attributes: attributes)
        }
    }
}

@PlainSystem
struct PrintCullingStatsSystem {
    @FilterQuery<Transform, VisibleEntities, With<SweepCamera>>
    private var cameras

    @Query<Ref<CullingStatsTimer>>
    private var timers

    @Res<DeltaTime>
    private var deltaTime

    init(world: World) { }

    func update(context: UpdateContext) {
        guard let camera = cameras.first else {
            return
        }

        timers.forEach { timer in
            timer.elapsed += deltaTime.deltaTime
            guard timer.elapsed >= 1 else {
                return
            }

            timer.elapsed = 0
            print("cameraX: \(Int(camera.0.position.x)), visibleEntities: \(camera.1.entityIds.count)")
        }
    }
}
