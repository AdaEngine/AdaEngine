import AdaEngine

// Helper for Collision Groups (if not already part of AdaEngine globally)
// It's an OptionSet, so it can be used like: CollisionGroup([.group(0), .group(1)])
// Or define static properties for clarity if preferred.
public extension CollisionGroup {
    static func group(_ bitIndex: Int) -> CollisionGroup {
        precondition(bitIndex >= 0 && bitIndex < 64, "Bit index must be between 0 and 63.")
        return CollisionGroup(rawValue: 1 << bitIndex)
    }

    // For combining, OptionSet allows array initialization: CollisionGroup([.group(0), .group(1)])
    // or .all, .default
}

// Source IDs for our tile types
enum TileSourceIDs {
    static let ground: Int = 1
    static let obstacle: Int = 2
    static let collectible: Int = 3
}

// Player Movement Script
class PlayerMovementScript: ScriptableComponent {

    var moveSpeed: Float = 200
    var jumpForce: Float = 25000 // Needs tuning

    override func update(deltaTime: Float) {
        guard let physicsBody = entity?.components[PhysicsBody2DComponent.self] else {
            return
        }

        var horizontalMovement: Float = 0
        if Input.isKeyPressed(.arrowRight) {
            horizontalMovement += 1
        }
        if Input.isKeyPressed(.arrowLeft) {
            horizontalMovement -= 1
        }

        // Apply horizontal velocity directly for responsive control
        var currentVelocity = physicsBody.linearVelocity
        currentVelocity.x = horizontalMovement * moveSpeed * deltaTime * 50 // deltaTime compensation + multiplier
        physicsBody.linearVelocity = currentVelocity

        if Input.isKeyPressed(.arrowUp) { // Simple jump
            // Check if grounded (optional, for now just jump)
            physicsBody.applyLinearImpulse(Vector2(0, jumpForce) * deltaTime, point: physicsBody.worldCenter, wake: true)
        }
    }
}

// Collectible Collision Handler Script
class CollectibleScript: ScriptableComponent {
    override func onCollisionEnter(with other: Entity) {
        // Check if the collision is with the player
        if other.name == "Player" {
            print("Player collected \(self.entity?.name ?? "collectible")!")
            self.entity?.removeFromScene() // Remove collectible
        }
    }
}


public struct TileMapPhysicsScene: SceneFunction {

    public func setup(scene: Scene, game: Game) {
        // 1. Basic Scene Setup
        scene.debugOptions.insert(.showPhysicsShapes) // Visualize physics shapes

        // 2. Create Programmatic Images & TileSet
        let tileSet = TileSet()

        let greenImage = Image(width: 16, height: 16, color: .green)
        let redImage = Image(width: 16, height: 16, color: .red)
        let yellowImage = Image(width: 16, height: 16, color: .yellow)
        let blueImage = Image(width: 16, height: 16, color: .blue) // For player

        // Ground Source
        let groundSource = TextureAtlasTileSource(from: greenImage, size: [16, 16], margin: .zero)
        groundSource.id = TileSourceIDs.ground
        var groundTileData = TileData()
        groundTileData.useCollisition = true
        groundTileData.physicsBody = PhysicsBody2DShapeDefinition(shapes: [.generateBox(size: [1,1])])
        groundSource.createTile(for: [0,0], data: groundTileData)
        tileSet.addTileSource(groundSource)

        // Obstacle Source
        let obstacleSource = TextureAtlasTileSource(from: redImage, size: [16, 16], margin: .zero)
        obstacleSource.id = TileSourceIDs.obstacle
        var obstacleTileData = TileData()
        obstacleTileData.useCollisition = true
        obstacleTileData.physicsBody = PhysicsBody2DShapeDefinition(shapes: [.generateBox(size: [1,1])])
        obstacleSource.createTile(for: [0,0], data: obstacleTileData)
        tileSet.addTileSource(obstacleSource)

        // Collectible Source
        let collectibleSource = TextureAtlasTileSource(from: yellowImage, size: [16, 16], margin: .zero)
        collectibleSource.id = TileSourceIDs.collectible
        var collectibleTileData = TileData()
        collectibleTileData.useCollisition = true // Will be set to trigger
        collectibleTileData.physicsBody = PhysicsBody2DShapeDefinition(shapes: [.generateBox(size: [0.5,0.5])]) // Smaller trigger shape
        collectibleSource.createTile(for: [0,0], data: collectibleTileData)
        tileSet.addTileSource(collectibleSource)

        // 3. TileMap and Layers
        let tileMap = TileMap()
        tileMap.tileSet = tileSet

        // Ground Layer
        let groundLayer = tileMap.createLayer()
        groundLayer.name = "GroundLayer"
        groundLayer.collisionFilter = CollisionFilter(
            categoryBitMask: .group(0), 
            collisionBitMask: .group(1) // Collides with Player
        )
        for x in -10..<10 { // Create a ground platform
            groundLayer.setCell(at: [x, -5], sourceId: TileSourceIDs.ground, atlasCoordinates: [0,0])
        }
        groundLayer.setCell(at: [-8, -3], sourceId: TileSourceIDs.ground, atlasCoordinates: [0,0])
        groundLayer.setCell(at: [-7, -3], sourceId: TileSourceIDs.ground, atlasCoordinates: [0,0])


        // Obstacle Layer
        let obstacleLayer = tileMap.createLayer()
        obstacleLayer.name = "ObstacleLayer"
        obstacleLayer.collisionFilter = CollisionFilter(
            categoryBitMask: .group(2), 
            collisionBitMask: CollisionGroup([.group(0), .group(1)]) // Collides with Ground and Player
        )
        for y in -4..<0 { // Create a wall
            obstacleLayer.setCell(at: [5, y], sourceId: TileSourceIDs.obstacle, atlasCoordinates: [0,0])
        }
        obstacleLayer.setCell(at: [-10, 0], sourceId: TileSourceIDs.obstacle, atlasCoordinates: [0,0]) // Floating obstacle


        // Collectible Layer
        let collectibleLayer = tileMap.createLayer()
        collectibleLayer.name = "CollectibleLayer"
        collectibleLayer.collisionFilter = CollisionFilter(
            categoryBitMask: .group(3), 
            collisionBitMask: .group(1) // Collides with Player (as trigger)
        )
        // Tiles on this layer will have their Collision2DComponent mode set to .trigger by TileMapSystem later.
        // We need a way to communicate this to TileMapSystem.
        // For now, the example will manually iterate and adjust created tile entities if TileMapSystem doesn't support it directly.
        collectibleLayer.setCell(at: [0, -3], sourceId: TileSourceIDs.collectible, atlasCoordinates: [0,0])
        collectibleLayer.setCell(at: [2, -3], sourceId: TileSourceIDs.collectible, atlasCoordinates: [0,0])
        collectibleLayer.setCell(at: [-7, -1], sourceId: TileSourceIDs.collectible, atlasCoordinates: [0,0])


        let tileMapEntity = Entity(name: "ExampleTileMap")
        tileMapEntity.components += TileMapComponent(tileMap: tileMap)
        tileMapEntity.components += Transform() // Position at origin
        scene.addEntity(tileMapEntity)
        
        // Post-process collectible tiles to make them triggers
        // This is a workaround. Ideally, TileMapSystem or TileData would specify trigger mode.
        scene.subscribe(to: SceneEvents.UpdateBegan.self) { _ in
             // Run once after TileMapSystem has created entities
            if let tmComponent = tileMapEntity.components[TileMapComponent.self] {
                if let collectibleLayerEntity = tmComponent.tileLayers[collectibleLayer.id] {
                    for tileChild in collectibleLayerEntity.children {
                        if var collisionComp = tileChild.components[Collision2DComponent.self] {
                            if collisionComp.mode != .trigger { // Avoid redundant sets
                                collisionComp.mode = .trigger
                                tileChild.components += collisionComp // Re-assign to apply change
                                tileChild.components += CollectibleScript() // Add script to handle collection
                            }
                        }
                    }
                }
            }
        }.store(in: &scene.subscriptions)


        // 4. Player Entity
        let playerEntity = Entity(name: "Player")
        playerEntity.components += Transform(scale: [0.8, 0.8, 1], position: [-5, -2, 0]) // Start above ground
        
        let playerSprite = SpriteComponent(texture: blueImage)
        playerEntity.components += playerSprite
        
        playerEntity.components += PhysicsBody2DComponent(
            shapes: [.generateBox(size: [0.8, 0.8])], // Player physics shape
            mass: 1.0,
            mode: .dynamic,
            filter: CollisionFilter(
                categoryBitMask: .group(1), 
                collisionBitMask: CollisionGroup([.group(0), .group(2), .group(3)]) // Collides with Ground, Obstacles, Collectibles
            )
        )
        playerEntity.components += PlayerMovementScript()
        scene.addEntity(playerEntity)

        // 5. Camera
        let cameraEntity = Entity(name: "Camera")
        let camera = Camera()
        camera.projection = .orthographic
        camera.orthographicScale = 7 // Zoom out to see more of the scene
        cameraEntity.components += camera
        cameraEntity.components += Transform(position: [0,0,10]) // Position camera
        scene.addEntity(cameraEntity)
    }
}

// Main application setup (will be in a separate main.swift)
// struct TileMapPhysicsApp: AdaEngineApp {
//     var scene: SceneFunction = TileMapPhysicsScene()
// 
//     var body: some AppScene {
//         GameScene {
//             EngineSetup(appName: "TileMapPhysicsExample", bundle: .main)
//         }
//     }
// }
//
// TileMapPhysicsApp.main()

// Placeholder for main.swift content if creating it in the same block
// For now, this file focuses on TileMapPhysicsScene.swift
