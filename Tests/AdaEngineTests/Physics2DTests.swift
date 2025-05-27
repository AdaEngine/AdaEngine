//
//  Physics2DTests.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 26.02.2025.
//

import Testing
@testable import AdaEngine

@MainActor
struct Physics2DTests {
    
    let world: World
    
    init() async throws {
        try Application.prepareForTest()
        
        let world = World()
        self.world = world
        self.world.addPlugin(DefaultWorldPlugin())
        world.build()
    }
    
    @Test
    func createStaticBody() async throws {
        let entity = Entity(name: "StaticBodyTestEntity")
        
        let collision = Collision2DComponent(
            shapes: [.generateBox()],
            mode: .default
        )
        
        entity.components += collision
        entity.components += Transform(position: [0, -10, 0])
        
        world.addEntity(entity)
        await world.update(1.0 / 60.0)
        
        let runtimeBody = try #require(entity.components[Collision2DComponent.self]?.runtimeBody)
        #expect(runtimeBody.getPosition() == [0, -10])
    }
    
    @Test
    func dynamicBodyFalling() async {
        let ground = Entity(name: "Ground_DynamicFallTest")
        let groundShape = Shape2DResource.generateBox(width: 100, height: 10)
        let groundCollision = Collision2DComponent(shapes: [groundShape], mode: .default)
        ground.components.set(groundCollision)
        ground.components += Transform(position: [0, -10, 0])
        world.addEntity(ground)
        
        let box = Entity(name: "Box_DynamicFallTest")
        let boxShape = Shape2DResource.generateBox(width: 1, height: 1)
        let boxCollision = PhysicsBody2DComponent(
            shapes: [boxShape],
            mass: 1,
            mode: .dynamic
        )
        box.components += boxCollision
        box.components += Transform(position: [0, 10, 0])
        world.addEntity(box)
        
        let startY = box.components[Transform.self]?.position.y ?? 0
        
        for _ in 0..<60 {
            await world.update(1.0 / 60.0)
        }
        
        let endY = box.components[Transform.self]?.position.y ?? 0
        #expect(endY < startY)
        #expect(endY > -9)
    }
    
    @Test
    func applyForce() async {
        let box = Entity(name: "Box_ApplyForceTest")
        let physicsBody = PhysicsBody2DComponent(
            shapes: [.generateBox()],
            mass: 1,
            mode: .dynamic
        )
        box.components += physicsBody
        box.components += Transform(position: .zero)
        world.addEntity(box)
        
        await world.update(1.0 / 60.0)
        box.components[PhysicsBody2DComponent.self]?.applyForceToCenter([100, 0], wake: true)
        
        await world.update(1.0 / 60.0)
        
        let finalVelocity = box.components[PhysicsBody2DComponent.self]!.linearVelocity.x
        #expect(finalVelocity > 0) 

        box.removeFromScene()
    }
    
//    @Test
//    func collisionEvent() async {
//        var collisionOccurred = false
//        
//        let entityA = Entity(name: "EntityA_CollisionEventTest")
//        let entityB = Entity(name: "EntityB_CollisionEventTest")
//        
//        let eventSubscription = world.eventManager.subscribe(to: CollisionEvents.Began.self) { event in
//            if (event.entityA == entityA && event.entityB == entityB) || (event.entityA == entityB && event.entityB == entityA) {
//                collisionOccurred = true
//            }
//        }
//        
//        let boxShape = Shape2DResource.generateBox(width: 1, height: 1)
//        
//        let bodyA = PhysicsBody2DComponent(shapes: [boxShape], mass: 1, mode: .dynamic)
//        let bodyB = PhysicsBody2DComponent(shapes: [boxShape], mass: 1, mode: .dynamic) // Both dynamic for more interaction
//        
//        entityA.components += bodyA
//        entityB.components += bodyB
//        
//        entityA.components += Transform(position: [-0.6, 0, 0]) // Start slightly apart
//        entityB.components += Transform(position: [0.6, 0, 0])
//        
//        world.addEntity(entityA)
//        world.addEntity(entityB)
//
//        await world.update(1.0 / 60.0) // Initial update
//
//        // Move them towards each other
//        entityA.components[PhysicsBody2DComponent.self]?.linearVelocity = [10, 0]
//        entityB.components[PhysicsBody2DComponent.self]?.linearVelocity = [-10, 0]
//
//        for _ in 0..<30 { 
//            if collisionOccurred { break }
//            await world.update(1.0 / 60.0)
//        }
//
//        eventSubscription.cancel()
//        #expect(collisionOccurred)
//    }
}

// MARK: - TileMap Physics Tests
//
//@MainActor
//struct TileMapPhysicsTests {
//
//    var scene: Scene! // Implicitly unwrapped optional, will be set in init or per-test setup
//    var tileSet: AdaEngine.TileSet!
//    var tileSource: TextureAtlasTileSource!
//
//    let collidableTileSourceId = 12345 
//    let fixedTimeStep = 1.0 / 60.0
//
//    // Helper to set up a scene for each test to ensure isolation
//    private mutating func initializeTestEnvironment() async throws {
//        try Application.prepareForTest() // Ensures engine context is ready
//        scene = Scene()
//        scene.readyIfNeeded() // Ensure systems like Physics2DSystem and TileMapSystem are registered and ready.
//        setupTileSet()
//    }
//
//    private mutating func setupTileSet() {
//        self.tileSet = AdaEngine.TileSet()
//        let dummyImage = Image(width: 16, height: 16, color: .red) // Minimal image
//        self.tileSource = TextureAtlasTileSource(
//            from: dummyImage,
//            size: SizeInt(width: 16, height: 16),
//            margin: .zero
//        )
//        self.tileSource.id = collidableTileSourceId
//        self.tileSet.addTileSource(self.tileSource)
//
//        let atlasCoord = PointInt(x: 0, y: 0) // The only tile type we'll use
//        var tileData = TileData()
//        tileData.useCollisition = true
//        // TileMapSystem defaults to a 1x1 box shape if physicsBody is nil.
//        // The physics shape size relative to the grid cell is important.
//        // Let's assume physics shapes are 1x1 world units, and grid cells are also 1x1 world units.
//        // TileMapSystem will place entities at (cell.x, cell.y)
//        tileData.physicsBody = PhysicsBody2DShapeDefinition(shapes: [.generateBox(size: [1,1])])
//        self.tileSource.createTile(for: atlasCoord, data: tileData)
//    }
//
//    private func createTileMapEntity(tileMap: AdaEngine.TileMap, name: String = "TestTileMapEntity") -> Entity {
//        let tileMapEntity = Entity(name: name)
//        tileMapEntity.components += TileMapComponent(tileMap: tileMap)
//        tileMapEntity.components += Transform() 
//        scene.addEntity(tileMapEntity)
//        return tileMapEntity
//    }
//    
//    private func getLayerEntityFromTileMap(tileMapEntity: Entity, layerId: Int) -> Entity? {
//        guard let tileMapComponent = tileMapEntity.components[TileMapComponent.self] else {
//            return nil
//        }
//        return tileMapComponent.tileLayers[layerId]
//    }
//
//    // Test Scenario 1: Tile-to-Tile Collision (Same Layer, Default Filter)
//    @Test("Tile-to-Tile (Same Layer, Default Filter)")
//    func tileToTileCollision_SameLayer_DefaultFilter() async throws {
//        try await initializeTestEnvironment()
//        var collisionDetected = false
//        var eventSubscription: Cancellable? = nil
//
//        let tileMap = AdaEngine.TileMap()
//        tileMap.tileSet = self.tileSet
//
//        let layer = tileMap.createLayer()
//        layer.name = "Layer_SameLayerTest"
//        // Default CollisionFilter: category 1 (.group(0)), mask all.
//        layer.collisionFilter = CollisionFilter(categoryBitMask: .group(0), collisionBitMask: .all) 
//        
//        // Place Tile A (static)
//        layer.setCell(at: PointInt(x: 0, y: 0), sourceId: collidableTileSourceId, atlasCoordinates: PointInt(x:0, y:0))
//        let tileMapEntity = createTileMapEntity(tileMap: tileMap)
//        scene.update(fixedTimeStep) // Allow TileMapSystem to process and create tile entities
//
//        // Dynamic "Probe" Entity acting as Tile B, with the same filter as Layer
//        let probeTileB = Entity(name: "ProbeTileB_SameLayer")
//        probeTileB.components += Transform(position: Vector3(0.9, 0, 0)) // Positioned to collide with Tile A at (0,0)
//        probeTileB.components += PhysicsBody2DComponent(
//            shapes: [.generateBox(size: [1,1])],
//            mass: 1,
//            mode: .dynamic,
//            filter: layer.collisionFilter // Same filter as the layer
//        )
//        scene.addEntity(probeTileB)
//        scene.update(fixedTimeStep) // Register probe
//
//        eventSubscription = scene.eventManager.subscribe(to: CollisionEvents.Began.self) { event in
//            let isProbeInvolved = event.entityA == probeTileB || event.entityB == probeTileB
//            let layerEntity = self.getLayerEntityFromTileMap(tileMapEntity: tileMapEntity, layerId: layer.id)
//            let isTileAInvolved = layerEntity?.children.contains(where: { $0 == event.entityA || $0 == event.entityB }) ?? false
//            
//            if isProbeInvolved && isTileAInvolved {
//                collisionDetected = true
//            }
//        }
//
//        for _ in 0..<30 { if collisionDetected { break }; scene.update(fixedTimeStep) }
//        #expect(collisionDetected)
//        eventSubscription?.cancel()
//    }
//
//    // Test Scenario 2: Tile-to-Tile Collision (Different Layers, Specific Filters)
//    @Test("Tile-to-Tile (Different Layers, Matching Filters)")
//    func tileToTileCollision_DifferentLayers_MatchingFilters() async throws {
//        try await initializeTestEnvironment()
//        var collisionDetected = false
//        var eventSubscription: Cancellable? = nil
//
//        let tileMap = AdaEngine.TileMap()
//        tileMap.tileSet = self.tileSet
//
//        let layerA = tileMap.createLayer()
//        layerA.name = "LayerA_Matching"
//        layerA.collisionFilter = CollisionFilter(categoryBitMask: .group(1), collisionBitMask: .group(2))
//
//        let layerB = tileMap.createLayer() // This layer's tile will be static
//        layerB.name = "LayerB_Matching"
//        layerB.collisionFilter = CollisionFilter(categoryBitMask: .group(2), collisionBitMask: .group(1))
//        layerB.setCell(at: PointInt(x: 0, y: 0), sourceId: collidableTileSourceId, atlasCoordinates: PointInt(x:0, y:0)) // Static Tile on Layer B
//
//        let tileMapEntity = createTileMapEntity(tileMap: tileMap)
//        scene.update(fixedTimeStep)
//
//        // Dynamic "Probe" Entity acting as a tile from Layer A
//        let probeTileA = Entity(name: "ProbeTileA_Matching")
//        probeTileA.components += Transform(position: Vector3(0.1, 0.1, 0)) // Position to collide
//        probeTileA.components += PhysicsBody2DComponent(
//            shapes: [.generateBox(size: [1,1])],
//            mass: 1,
//            mode: .dynamic,
//            filter: layerA.collisionFilter // Use LayerA's filter
//        )
//        scene.addEntity(probeTileA)
//        scene.update(fixedTimeStep)
//
//        eventSubscription = scene.eventManager.subscribe(to: CollisionEvents.Began.self) { event in
//            let isProbeInvolved = event.entityA == probeTileA || event.entityB == probeTileA
//            let layerBEntity = self.getLayerEntityFromTileMap(tileMapEntity: tileMapEntity, layerId: layerB.id)
//            let isTileBInvolved = layerBEntity?.children.contains(where: { $0 == event.entityA || $0 == event.entityB }) ?? false
//
//            if isProbeInvolved && isTileBInvolved {
//                collisionDetected = true
//            }
//        }
//        
//        for _ in 0..<30 { if collisionDetected { break }; scene.update(fixedTimeStep) }
//        #expect(collisionDetected)
//        eventSubscription?.cancel()
//    }
//
//    // Test Scenario 3: Tile-to-Tile No Collision (Different Layers, Non-Matching Filters)
//    @Test("Tile-to-Tile (Different Layers, Non-Matching Filters)")
//    func tileToTileNoCollision_DifferentLayers_NonMatchingFilters() async throws {
//        try await initializeTestEnvironment()
//        var collisionDetected = false
//        var eventSubscription: Cancellable? = nil
//
//        let tileMap = AdaEngine.TileMap()
//        tileMap.tileSet = self.tileSet
//
//        let layerC = tileMap.createLayer(); layerC.name = "LayerC_NonMatch"
//        layerC.collisionFilter = CollisionFilter(categoryBitMask: .group(1), collisionBitMask: .group(1))
//
//        let layerD = tileMap.createLayer(); layerD.name = "LayerD_NonMatch" // Static tile on Layer D
//        layerD.collisionFilter = CollisionFilter(categoryBitMask: .group(4), collisionBitMask: .group(4))
//        layerD.setCell(at: PointInt(x: 0, y: 0), sourceId: collidableTileSourceId, atlasCoordinates: PointInt(x:0, y:0))
//
//        let tileMapEntity = createTileMapEntity(tileMap: tileMap)
//        scene.update(fixedTimeStep)
//
//        // Dynamic "Probe" Entity acting as a tile from Layer C
//        let probeTileC = Entity(name: "ProbeTileC_NonMatch")
//        probeTileC.components += Transform(position: Vector3(0.1, 0.1, 0))
//        probeTileC.components += PhysicsBody2DComponent(
//            shapes: [.generateBox(size: [1,1])],
//            mass: 1,
//            mode: .dynamic,
//            filter: layerC.collisionFilter // Use LayerC's filter
//        )
//        scene.addEntity(probeTileC)
//        scene.update(fixedTimeStep)
//
//        eventSubscription = scene.eventManager.subscribe(to: CollisionEvents.Began.self) { event in
//            let isProbeInvolved = event.entityA == probeTileC || event.entityB == probeTileC
//            let layerDEntity = self.getLayerEntityFromTileMap(tileMapEntity: tileMapEntity, layerId: layerD.id)
//            let isTileDInvolved = layerDEntity?.children.contains(where: { $0 == event.entityA || $0 == event.entityB }) ?? false
//            
//            if isProbeInvolved && isTileDInvolved {
//                collisionDetected = true
//            }
//        }
//
//        for _ in 0..<30 { if collisionDetected { break }; scene.update(fixedTimeStep) }
//        #expect(!collisionDetected)
//        eventSubscription?.cancel()
//    }
//
//    // Test Scenario 4: Tile-to-External-Entity Collision
//    @Test("Tile-to-External Entity (Collision)")
//    func tileToExternalEntityCollision() async throws {
//        try await initializeTestEnvironment()
//        var collisionDetected = false
//        var eventSubscription: Cancellable? = nil
//
//        let tileMap = AdaEngine.TileMap(); tileMap.tileSet = self.tileSet
//        let layerE = tileMap.createLayer(); layerE.name = "LayerE_ExtCollide"
//        layerE.collisionFilter = CollisionFilter(categoryBitMask: .group(1), collisionBitMask: .group(2))
//        layerE.setCell(at: PointInt(x: 0, y: 0), sourceId: collidableTileSourceId, atlasCoordinates: PointInt(x:0, y:0))
//        
//        let tileMapEntity = createTileMapEntity(tileMap: tileMap)
//        scene.update(fixedTimeStep)
//
//        let externalEntity = Entity(name: "External_MatchingToE")
//        externalEntity.components += Transform(position: Vector3(0.1, 0.1, 0))
//        externalEntity.components += PhysicsBody2DComponent(
//            shapes: [.generateBox(size: [1,1])], mass: 1, mode: .dynamic,
//            filter: CollisionFilter(categoryBitMask: .group(2), collisionBitMask: .group(1)) // Matches LayerE
//        )
//        scene.addEntity(externalEntity)
//        scene.update(fixedTimeStep)
//        
//        eventSubscription = scene.eventManager.subscribe(to: CollisionEvents.Began.self) { event in
//            let isExternalInvolved = event.entityA == externalEntity || event.entityB == externalEntity
//            let layerEEntity = self.getLayerEntityFromTileMap(tileMapEntity: tileMapEntity, layerId: layerE.id)
//            let isTileInvolved = layerEEntity?.children.contains(where: { $0 == event.entityA || $0 == event.entityB }) ?? false
//
//            if isExternalInvolved && isTileInvolved {
//                collisionDetected = true
//            }
//        }
//
//        for _ in 0..<30 { if collisionDetected { break }; scene.update(fixedTimeStep) }
//        #expect(collisionDetected)
//        eventSubscription?.cancel()
//    }
//
//    // Test Scenario 5: Tile-to-External-Entity No Collision
//    @Test("Tile-to-External Entity (No Collision)")
//    func tileToExternalEntityNoCollision() async throws {
//        try await initializeTestEnvironment()
//        var collisionDetected = false
//        var eventSubscription: Cancellable? = nil
//
//        let tileMap = AdaEngine.TileMap(); tileMap.tileSet = self.tileSet
//        let layerF = tileMap.createLayer(); layerF.name = "LayerF_ExtNoCollide"
//        layerF.collisionFilter = CollisionFilter(categoryBitMask: .group(1), collisionBitMask: .group(1))
//        layerF.setCell(at: PointInt(x: 0, y: 0), sourceId: collidableTileSourceId, atlasCoordinates: PointInt(x:0, y:0))
//
//        let tileMapEntity = createTileMapEntity(tileMap: tileMap)
//        scene.update(fixedTimeStep)
//
//        let externalEntity = Entity(name: "External_NonMatchingToF")
//        externalEntity.components += Transform(position: Vector3(0.1, 0.1, 0))
//        externalEntity.components += PhysicsBody2DComponent(
//            shapes: [.generateBox(size: [1,1])], mass: 1, mode: .dynamic,
//            filter: CollisionFilter(categoryBitMask: .group(8), collisionBitMask: .group(8)) // Does NOT match LayerF
//        )
//        scene.addEntity(externalEntity)
//        scene.update(fixedTimeStep)
//
//        eventSubscription = scene.eventManager.subscribe(to: CollisionEvents.Began.self) { event in
//            let isExternalInvolved = event.entityA == externalEntity || event.entityB == externalEntity
//            let layerFEntity = self.getLayerEntityFromTileMap(tileMapEntity: tileMapEntity, layerId: layerF.id)
//            let isTileInvolved = layerFEntity?.children.contains(where: { $0 == event.entityA || $0 == event.entityB }) ?? false
//            
//            if isExternalInvolved && isTileInvolved {
//                collisionDetected = true
//            }
//        }
//
//        for _ in 0..<30 { if collisionDetected { break }; scene.update(fixedTimeStep) }
//        #expect(!collisionDetected)
//        eventSubscription?.cancel()
//    }
//}
//
//// Helper extension for CollisionGroup if not already globally available for tests
//// Ensure this is not duplicating an existing extension if AdaEngine provides it.
//// Using .group(0) for category 1, .group(1) for category 2, etc.
//extension CollisionGroup {
//    static func group(_ bitIndex: Int) -> CollisionGroup {
//        precondition(bitIndex >= 0 && bitIndex < 64, "Bit index must be between 0 and 63.")
//        return CollisionFilter.CollisionGroup(rawValue: 1 << bitIndex)
//    }
//}
