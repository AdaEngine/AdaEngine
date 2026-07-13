import AdaEngine

@main
struct LargeBox2DBenchmarkExample: App {
    var body: some AppScene {
        GameAppScene {
            Scene(from: World())
        }
        .addPlugins(DefaultPlugins()
            .disable(AudioPlugin.self)
            .disable(TextPlugin.self)
            .disable(Core3DPlugin.self)
            .disable(Light2DPlugin.self)
            .disable(UIPlugin.self)
            .disable(ContextMenuPlugin.self)
            .disable(TileMapPlugin.self)
            .disable(Physics2DPlugin.self)
            .set(LargeBox2DPhysicsConfigurationPlugin())
            .set(Physics2DPlugin())
            .set(LargeBox2DBenchmarkPlugin())
        )
        .windowMode(.windowed)
        .windowTitle("16,000 Box2D Bodies")
    }
}

private struct LargeBox2DPhysicsConfigurationPlugin: Plugin {
    func setup(in app: AppWorlds) {
        app.insertResource(
            PhysicsSimulationThreading(
                workerCount: 8,
                box2DWorkerCount: 8
            )
        )
    }
}

private struct LargeBox2DBenchmarkPlugin: Plugin {
    func setup(in app: AppWorlds) {
        app.main.spawn(
            "Camera",
            bundle: OrthographicCameraBundle(
                camera: Camera().setBackgroundColor(Color.fromHex(0x171A1F))
            )
        )
        app.addSystem(LargeBox2DBenchmarkSetupSystem.self, on: .startup)
    }
}

@System
func LargeBox2DBenchmarkSetup(_ commands: Commands) {
    let columns = 160
    let rows = 100
    let boxSize: Float = 5
    let spacing: Float = 5.4
    let totalWidth = Float(columns - 1) * spacing
    let totalHeight = Float(rows - 1) * spacing
    let shape = Shape2DResource.generateBox(width: boxSize, height: boxSize)
    let texture = AssetHandle(Texture2D.whiteTexture)

    commands.spawn("Floor") {
        PhysicsBody2DComponent(
            shapes: [Shape2DResource.generateBox(width: totalWidth + 80, height: 20)],
            mode: .static
        )
        Transform(position: [0, -totalHeight / 2 - 30, 0])
    }

    for row in 0..<rows {
        for column in 0..<columns {
            let x = Float(column) * spacing - totalWidth / 2
            let y = Float(row) * spacing - totalHeight / 2
            let tint = row.isMultiple(of: 2)
                ? Color.fromHex(0xD7B899)
                : Color.fromHex(0xAFC7DF)

            commands.spawn("Box \(row)-\(column)") {
                Sprite(
                    texture: texture,
                    tintColor: tint,
                    size: Size(width: boxSize, height: boxSize)
                )
                PhysicsBody2DComponent(
                    shapes: [shape],
                    mass: 1,
                    material: PhysicsMaterial.generate(
                        friction: 0.35,
                        restitution: 0.05,
                        density: 1
                    ),
                    mode: .dynamic
                )
                Transform(position: [x, y, 0])
            }
        }
    }
}
