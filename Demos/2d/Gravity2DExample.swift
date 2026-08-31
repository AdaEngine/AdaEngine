//
//  Gravity2DExample.swift
//  AdaEngine
//

import AdaEngine

@main
struct Gravity2DExampleApp: App {
    var body: some AppScene {
        DefaultAppWindow()
            .addPlugins(Gravity2DExamplePlugin())
            .windowMode(.windowed)
            .windowTitle("Gravity 2D Swarm")
    }
}

struct Gravity2DExamplePlugin: Plugin {
    private let colors: [Color] = [
        .blue,
        .mint,
        .orange,
        .pink,
        .yellow
    ]

    func setup(in app: borrowing AppWorlds) {
        GravityVelocity.registerComponent()
        GravityPulse.registerComponent()

        setupScene(in: app.main)
        loadGravityPlugin(in: app)
    }

    private func setupScene(in world: World) {
        world.spawn(bundle: Camera2D())
        world.spawn("Background") {
            Sprite(
                texture: Texture2D.whiteTexture,
                tintColor: Color(red: 0.035, green: 0.045, blue: 0.08, alpha: 1),
                size: Size(width: 1_000, height: 650)
            )
            Transform(position: Vector3(0, 0, -1))
        }

        for index in 0..<20 {
            let column = index % 5
            let row = index / 5
            let directionX: Float = index.isMultiple(of: 2) ? 1 : -1
            let directionY: Float = row.isMultiple(of: 2) ? 1 : -1

            world.spawn("Gravity Dot \(index + 1)") {
                Sprite(
                    texture: Texture2D.whiteTexture,
                    tintColor: colors[index % colors.count],
                    size: Size(width: 42, height: 42)
                )
                Transform(
                    position: Vector3(
                        Float(column - 2) * 145,
                        Float(row) * 115 - 170,
                        Float(index) * 0.001
                    )
                )
                GravityVelocity(
                    velocity: Vector2(
                        directionX * Float(70 + column * 13),
                        directionY * Float(55 + row * 17)
                    ),
                    boundsMin: Vector2(-450, -270),
                    boundsMax: Vector2(450, 270)
                )
                GravityPulse(
                    phase: Float(index) / 20,
                    speed: 0.35 + Float(index % 4) * 0.08,
                    minimumScale: 0.65,
                    maximumScale: 1.25
                )
            }
        }
    }

    @MainActor
    private func loadGravityPlugin(in app: borrowing AppWorlds) {
        guard let scriptURL = Bundle.module.url(
            forResource: "gravity_swarm",
            withExtension: "gravity",
            subdirectory: "Resources/Gravity"
        ) else {
            print("Gravity2DExample: Resources/Gravity/gravity_swarm.gravity is missing")
            return
        }

        do {
            let gravityPlugin = try GravityScriptPlugin(contentsOf: scriptURL)
            app.addPlugin(gravityPlugin)
            print("Gravity2DExample: loaded \(gravityPlugin.name)")
        } catch {
            print("Gravity2DExample: failed to load script: \(error)")
        }
    }
}

@Component
struct GravityVelocity: Codable, Sendable {
    var velocity: Vector2
    var boundsMin: Vector2
    var boundsMax: Vector2
}

@Component
struct GravityPulse: Codable, Sendable {
    var phase: Float
    var speed: Float
    var minimumScale: Float
    var maximumScale: Float
}
