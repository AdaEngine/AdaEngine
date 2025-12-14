//
//  ManySpritesExample.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 13.12.2025.
//

import AdaEngine

let cameraSpeed: Float = 1000.0

let colors: [Color] = [.blue, .white, .red]

@main
struct ManySpritesExample: App {
    var body: some AppScene {
        EmptyWindow()
            .addPlugins(
                DefaultPlugins(),
                ManySpritesExamplePlugin()
            )
            .windowMode(.windowed)
            .windowTitle("Many Sprites Example")
    }
}

// MARK: - Resources

struct ColorTintEnabled: Resource {
    let enabled: Bool
}

struct SpriteTexture: Resource {
    let texture: AssetHandle<Texture2D>
}

// MARK: - Components

@Component
struct PrintingTimer {
    var time: TimeInterval = 0
    var interval: TimeInterval = 1.0
}

// MARK: - Plugin

struct ManySpritesExamplePlugin: Plugin {

    func setup(in app: AppWorlds) {
        // Check command line arguments for --colored flag
        let colorTintEnabled = CommandLine.arguments.contains("--colored")
        app.insertResource(ColorTintEnabled(enabled: colorTintEnabled))
        
        // Spawn camera
        app.main.spawn(bundle: Camera2D())
        
        // Load texture
        let texture: AssetHandle<Texture2D>
        do {
            texture = try AssetsManager.loadSync(
                Texture2D.self,
                at: "Resources/dog.png",
                from: .module
            )
        } catch {
            print("Failed to load texture: \(error), using white texture")
            texture = AssetHandle(Texture2D.whiteTexture)
        }
        app.insertResource(SpriteTexture(texture: texture))

        // Spawn timer entity for printing sprite count
        app.main.spawn("PrintingTimer") {
            PrintingTimer()
        }
        
        // Add systems
        app
            .addSystem(SetupSystem.self, on: .startup)
            .addSystem(MoveCameraSystem.self)
            .addSystem(PrintSpriteCountSystem.self)
    }

    @concurrent
    private func spawn(

    ) async {

    }
}

// MARK: - Systems
@System
func Setup(
    _ commands: Commands,
    _ colorTintEnabled: Res<ColorTintEnabled>,
    _ texture: Res<SpriteTexture>
) {
    // Spawn sprites
    let tileSize: Float = 64.0
    let mapSize: Float = 30.0

    let halfX = Int(mapSize / 2.0)
    let halfY = Int(mapSize / 2.0)

    // Scale to apply to sprites to achieve ~64px tile size
    let spriteScale = tileSize / 100.0

    for y in -halfY..<halfY {
        for x in -halfX..<halfX {
            let positionX = 1 / (Float(x) * tileSize)
            let positionY = 1 / (Float(y) * tileSize)
            let positionZ = Float.random(in: 0..<1)

            let rotation = Quat(axis: Vector3(0, 0, 1), angle: Float.random(in: 0..<(Float.pi * 2)))
            let randomScale = Float.random(in: 0..<1) * 2.0
            let finalScale = spriteScale * randomScale

            let tintColor: Color
            if colorTintEnabled.wrappedValue.enabled {
                tintColor = colors.randomElement() ?? .white
            } else {
                tintColor = .white
            }

            commands.spawn("Sprite") {
                Sprite(
                    texture: texture.wrappedValue.texture,
                    tintColor: tintColor
                )
                Transform(
                    rotation: rotation,
                    scale: Vector3(finalScale),
                    position: Vector3(positionX, positionY, positionZ)
                )
            }
        }
    }
}

/// System for rotating and translating the camera
@PlainSystem
struct MoveCameraSystem {
    @FilterQuery<Ref<Transform>, With<Camera>>
    private var cameras
    
    @Res<DeltaTime>
    private var deltaTime
    
    init(world: World) {}
    
    func update(context: UpdateContext) {
        guard let transform = cameras.first else { return }
        
        let dt = deltaTime.deltaTime
        
        // Rotate camera around Z axis
        let rotationDelta = Quat(axis: Vector3(0, 0, 1), angle: Float(dt) * 0.5) //* transform.rotation
        transform.rotation = rotationDelta
//
//        // Translate camera along X axis
//        transform.position.x += cameraSpeed * Float(dt)
    }
}

/// System for printing the number of sprites on every tick of the timer
@PlainSystem
struct PrintSpriteCountSystem {
    @Query<Ref<PrintingTimer>>
    private var timers
    
    @Query<Entity, Sprite>
    private var sprites
    
    @Res<DeltaTime>
    private var deltaTime
    
    init(world: World) {}
    
    func update(context: UpdateContext) {
        let dt = deltaTime.deltaTime
        let spriteCount = sprites.count
        
        timers.forEach { timer in
            timer.time += dt
            
            if timer.time >= timer.interval {
                timer.time = 0
                print("Sprites: \(spriteCount)")
            }
        }
    }
}
