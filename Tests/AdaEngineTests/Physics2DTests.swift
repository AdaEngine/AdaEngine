//
//  Physics2DTests.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 26.02.2025.
//

import Testing
import AdaECS
@_spi(Internal) @testable import AdaApp
@testable import AdaPhysics
import AdaTransform

@MainActor
struct Physics2DTests {
    
    let world: AppWorlds

    init() async throws {
        let world = AppWorlds(mainWorld: World())
        self.world = world
        world.insertResource(DefaultSchedulerOrder(order: [.update, .fixedUpdate, .postUpdate]))
        world.mainWorld.setSchedulers([
            .update,
            .fixedUpdate,
            .postUpdate
        ])

        world
            .addPlugin(Physics2DPlugin())
            .addPlugin(TransformPlugin())
        try world.build()
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
        world.mainWorld.flush()
        await world.mainWorld.runScheduler(.fixedUpdate, deltaTime: 1 / 60)
        
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
            await world.update()
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
        world.mainWorld.flush()
        await world.update()
        
        box.components[PhysicsBody2DComponent.self]?.applyForceToCenter([100, 0], wake: true)
        
        let initialVelocity = box.components[PhysicsBody2DComponent.self]!.linearVelocity.x
        
        await world.update()
        
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
}
