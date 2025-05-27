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
        let entity = Entity()
        
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
        let ground = Entity()
        let groundShape = Shape2DResource.generateBox(width: 100, height: 10)
        let groundCollision = Collision2DComponent(shapes: [groundShape], mode: .default)
        ground.components.set(groundCollision)
        ground.components += Transform(position: [0, -10, 0])
        world.addEntity(ground)
        
        let box = Entity()
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
        let box = Entity()
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
        
        let initialVelocity = box.components[PhysicsBody2DComponent.self]!.linearVelocity.x
        
        await world.update(1.0 / 60.0)
        
        let finalVelocity = box.components[PhysicsBody2DComponent.self]!.linearVelocity.x
        #expect(finalVelocity > initialVelocity)
    }
    
    // @Test
    // @MainActor
    // func collision() async {
    //     var collisionOccurred = false
        
    //     _ = world.eventManager.subscribe(to: CollisionEvents.Began.self) { event in
    //         collisionOccurred = true
    //     }
        
    //     let entityA = Entity()
    //     let entityB = Entity()
        
    //     let boxShape = Shape2DResource.generateBox(width: 1, height: 1)
        
    //     let collisionA = PhysicsBody2DComponent(
    //         shapes: [boxShape],
    //         mode: .kinematic
    //     )
        
    //     let collisionB = PhysicsBody2DComponent(
    //         shapes: [boxShape],
    //         mode: .kinematic
    //     )
        
    //     entityA.components.set(collisionA)
    //     entityB.components.set(collisionB)
        
    //     entityA.components += Transform(position: [-1, 0, 0])
    //     entityB.components += Transform(position: [1, 0, 0])
        
    //     world.addEntity(entityA)
    //     world.addEntity(entityB)
        
    //     await world.update(1.0 / 60.0)
        
    //     entityA.components[Transform.self]?.position.x += 1
    //     entityB.components[Transform.self]?.position.x -= 1
        
    //     for _ in 0..<10 {
    //         await world.update(1.0 / 60.0)
    //     }
        
    //     #expect(collisionOccurred)
    // }
    
    @Test
    func testStaticBodyTransformSync() async throws {
        let entity = Entity()
        
        let initialPosition = Vector2(1, 2)
        let initialAngle = Angle.degrees(45)
        
        var physicsBody = PhysicsBody2DComponent(
            shapes: [.generateBox()],
            mode: .static
        )
        entity.components += physicsBody
        entity.components += Transform(
            rotation: Quat(axis: Vector3(0, 0, 1), angle: initialAngle.radians),
            position: Vector3(initialPosition.x, initialPosition.y, 0)
        )
        
        world.addEntity(entity)
        await world.update(1.0 / 60.0)
        let newPosition = Vector2(3, 4)
        let newAngle = Angle.degrees(90)
        
        physicsBody = entity.components[PhysicsBody2DComponent.self]!
        physicsBody.runtimeBody?.setTransform(position: newPosition, angle: newAngle)
        entity.components[PhysicsBody2DComponent.self] = physicsBody // Re-assign to trigger potential updates
        
        await world.update(1.0 / 60.0)
        
        let finalTransform = entity.components[Transform.self]!
        
        #expect(abs(finalTransform.position.x - newPosition.x) < 0.001)
        #expect(abs(finalTransform.position.y - newPosition.y) < 0.001)
        #expect(abs(finalTransform.rotation.angle2D.degrees - newAngle.degrees) < 0.001)
    }
    
    @Test
    func testCollisionBodyTransformSync() async throws {
        let entity = Entity()
        
        let initialPosition = Vector2(5, 6)
        let initialAngle = Angle.degrees(30)
        
        var collisionBody = Collision2DComponent(
            shapes: [.generateBox()],
            mode: .default // Or .trigger, doesn't matter much for this test
        )
        entity.components += collisionBody
        entity.components += Transform(
            rotation: Quat(axis: Vector3(0, 0, 1), angle: initialAngle.radians),
            position: Vector3(initialPosition.x, initialPosition.y, 0),
        )
        
        world.addEntity(entity)
        
        await world.update(1.0 / 60.0)
        
        let newPosition = Vector2(7, 8)
        let newAngle = Angle.degrees(60)
        
        collisionBody = entity.components[Collision2DComponent.self]!
        collisionBody.runtimeBody?.setTransform(position: newPosition, angle: newAngle)
        entity.components[Collision2DComponent.self] = collisionBody // Re-assign to trigger potential updates
        
        await world.update(1.0 / 60.0)
        
        let finalTransform = entity.components[Transform.self]!
        
        #expect(abs(finalTransform.position.x - newPosition.x) < 0.001)
        #expect(abs(finalTransform.position.y - newPosition.y) < 0.001)
        #expect(abs(finalTransform.rotation.angle2D.degrees - newAngle.degrees) < 0.001)
    }
}
