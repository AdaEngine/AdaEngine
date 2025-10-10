//
//  BunnyExampleScene.swift
//
//
//  Created by Vladislav Prusakov on 06.06.2024.
//

import AdaEngine

enum BunnyExampleConstants {
    static let bunniesPerClick: Int = 10
    static let bunnyScale: Float = 1
    static let gravity: Float = -9.8
    static let maxVelocity: Float = 2050.0
}

/// A bunny stress test scene similar to bevymark.
/// Click to spawn bunnies that bounce around the screen with gravity simulation.
@MainActor
struct BunnyExample: Plugin {

    func setup(in app: AppWorlds) {
        setupCamera(in: app)
        loadAssets(in: app)
        setupUI(in: app)
        setupSystems(in: app)
    }
    
    private func setupCamera(in app: AppWorlds) {
    }
    
    private func loadAssets(in app: AppWorlds) {
        // Try to load a bunny texture, fallback to white texture if not available
        do {
            let image = try AssetsManager.loadSync(
                Image.self,
                at: "Assets/characters_packed.png",
                from: Bundle.editor
            ).asset
            let atlas = TextureAtlas(from: image, size: [20, 23], margin: [4, 1])
            app.insertResource(BunnyTexture(texture: AssetHandle(atlas[0, 0])))
        } catch {
            print("Could not load bunny texture, using white texture: \(error)")
            app.insertResource(BunnyTexture(texture: AssetHandle(Texture2D.whiteTexture)))
        }
    }
    
    private func setupUI(in app: AppWorlds) {
        // Create performance counter UI
        var container = TextAttributeContainer()
        container.foregroundColor = .white
        
        app.main.spawn("PerformanceCounter") {
            Text2DComponent(text: AttributedText("Bunnies: 0\nFPS: 0", attributes: container))
            Transform(scale: Vector3(0.1), position: [-9, 8, 1])
            NoFrustumCulling()
            PerformanceCounter()
        }
    }
    
    private func setupSystems(in app: AppWorlds) {
        app
            .addSystem(BunnySpawnerSystem.self)
            .addSystem(BunnyMovementSystem.self)
            .addSystem(BunnyCollisionSystem.self)
            .addSystem(PerformanceCounterSystem.self)
    }
}

// MARK: - Components

struct BunnyTexture: Resource {
    let texture: AssetHandle<Texture2D>
}

/// Component to mark bunny entities and store their velocity
@Component
struct Bunny {
    var velocity: Vector3
    
    init() {
        // Initialize with random velocity
        let velocityX = Float.random(in: -Self.maxInitialVelocity...Self.maxInitialVelocity)
        let velocityY = Float.random(in: 0...Self.maxInitialVelocity)
        self.velocity = Vector3(velocityX, velocityY, 0)
    }
    
    private static let maxInitialVelocity: Float = 9000.0
}

/// Component for the performance counter UI
@Component
struct PerformanceCounter {
    var bunnyCount: Int = 0
    var fps: Float = 0
    var frameCount: Int = 0
    var lastUpdateTime: TimeInterval = 0
}

// MARK: - Systems

/// System that spawns bunnies on mouse click
@PlainSystem
struct BunnySpawnerSystem {
    
    @Query<Camera, GlobalTransform>
    private var cameras

    @ResQuery
    private var bunnyTexture: BunnyTexture!

    @ResQuery
    private var input: Input!

    init(world: World) {}
    
    func update(context: inout UpdateContext) {
        guard input.isMouseButtonPressed(.left) else { return }

        // Get camera for world position conversion
        cameras.forEach { (camera, globalTransform) in
            let mousePosition = input.getMousePosition()
            guard let worldPosition = camera.viewportToWorld2D(
                cameraGlobalTransform: globalTransform.matrix,
                viewportPosition: mousePosition
            ) else { return }

            // Spawn multiple bunnies at mouse position
            for _ in 0 ..< BunnyExampleConstants.bunniesPerClick {
                spawnBunny(at: Vector3(worldPosition.x, -worldPosition.y, 0), world: context.world)
            }
        }
    }

    private func spawnBunny(at position: Vector3, world: World) {
        // Add small random offset to position
        let offsetX = Float.random(in: -2.5...2.5)
        let offsetY = Float.random(in: -2.5...2.5)
        let bunnyPosition = position + Vector3(offsetX, offsetY, 0)

        world.spawn("Bunny") {
            Bunny()
            Transform(
                scale: Vector3(BunnyExampleConstants.bunnyScale),
                position: bunnyPosition
            )
            SpriteComponent(
                texture: bunnyTexture.texture,
                tintColor: getRandomColor()
            )
        }
    }
    
    private func getRandomColor() -> Color {
        return Color(
            red: Float.random(in: 0.3...1.0),
            green: Float.random(in: 0.3...1.0),
            blue: Float.random(in: 0.3...1.0),
            alpha: 1
        )
    }
}

/// System that handles bunny movement with gravity
@PlainSystem
struct BunnyMovementSystem {
    
    @Query<Ref<Bunny>, Ref<Transform>>
    private var bunnies

    @ResQuery<DeltaTime>
    private var deltaTime

    init(world: World) {}
    
    func update(context: inout UpdateContext) {
        let deltaTime = deltaTime.deltaTime

        bunnies.forEach { (bunny, transform) in
            var velocity = bunny.velocity
            var position = transform.position
            
            // Apply gravity
            velocity.y += BunnyExampleConstants.gravity * deltaTime

            // Clamp velocity to maximum
            if velocity.length > BunnyExampleConstants.maxVelocity {
                velocity = velocity.normalized * BunnyExampleConstants.maxVelocity
            }
            
            // Update position
            position += velocity * deltaTime

            // Update components
            bunny.velocity = velocity
            transform.wrappedValue = Transform(
                rotation: transform.rotation,
                scale: transform.scale,
                position: position
            )
        }
    }
}

/// System that handles collision with screen boundaries
@PlainSystem
struct BunnyCollisionSystem {
    
    @FilterQuery<Camera, With<GlobalTransform>>
    private var cameras
    
    @Query<Entity, Ref<Bunny>, Transform>
    private var bunnies
    
    init(world: World) {}
    
    func update(context: inout UpdateContext) {
        // Get screen bounds from camera
        guard let camera = cameras.first else { return }
        
        let viewport = camera.viewport?.rect ?? Rect(x: 0, y: 0, width: 800, height: 600)
        let halfExtents = Vector2(Float(viewport.width / 6), Float(viewport.height / 6))

        // Convert to world coordinates (simplified approach)
        let worldHalfExtents = halfExtents * camera.orthographicScale / 100.0
        
        bunnies.forEach { (entity, bunny, transform) in
            var velocity = bunny.velocity
            var position = transform.position
            let halfBunnySize = BunnyExampleConstants.bunnyScale * 0.5

            // Check horizontal bounds
            if (velocity.x > 0 && position.x + halfBunnySize > worldHalfExtents.x) ||
               (velocity.x <= 0 && position.x - halfBunnySize < -worldHalfExtents.x) {
                velocity.x = -velocity.x
            }
            
            // Check vertical bounds
            if velocity.y < 0 && position.y - halfBunnySize < -worldHalfExtents.y {
                velocity.y = -velocity.y
            }
            
            // Check top bound (stop upward velocity)
            if position.y + halfBunnySize > worldHalfExtents.y && velocity.y > 0 {
                velocity.y = 0
            }
            
            // Keep bunny in bounds
            position.x = max(-worldHalfExtents.x + halfBunnySize, 
                           min(worldHalfExtents.x - halfBunnySize, position.x))
            position.y = max(-worldHalfExtents.y + halfBunnySize, 
                           min(worldHalfExtents.y - halfBunnySize, position.y))
            
            // Update components
            bunny.velocity = velocity
            entity.components += bunny.wrappedValue
            entity.components += Transform(
                rotation: transform.rotation,
                scale: transform.scale,
                position: position
            )
        }
    }
}

/// System that updates the performance counter
@PlainSystem
struct PerformanceCounterSystem {
    
    @Query<Entity, Bunny>
    private var bunnies
    
    @Query<Entity, Ref<PerformanceCounter>, Ref<Text2DComponent>>
    private var counters

    @ResQuery<DeltaTime>
    private var deltaTime

    init(world: World) {}
    
    func update(context: inout UpdateContext) {
        let bunnyCount = bunnies.count
        let deltaTime = deltaTime.deltaTime
        
        counters.forEach { (entity, counter, textComponent) in
            counter.bunnyCount = bunnyCount
            counter.frameCount += 1
            counter.lastUpdateTime += deltaTime
            
            // Update FPS calculation every second
            if counter.lastUpdateTime >= 1.0 {
                counter.fps = Float(counter.frameCount) / Float(counter.lastUpdateTime)
                counter.frameCount = 0
                counter.lastUpdateTime = 0
            }
            
            // Update text
//            var container = TextAttributeContainer()
//            container.foregroundColor = .white
            
            let text = "Bunnies: \(bunnyCount)\nFPS: \(String(format: "%.1f", counter.fps))"
            print(text)
//            textComponent.text = AttributedText(text, attributes: container)
            
            // Update entity components
//            entity.components += counter.wrappedValue
//            entity.components += textComponent.wrappedValue
        }
    }
}

