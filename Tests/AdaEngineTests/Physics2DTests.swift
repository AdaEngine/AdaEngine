//
//  Physics2DTests.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 26.02.2025.
//

import XCTest
@testable import AdaEngine

@MainActor
final class Physics2DTests: XCTestCase {
    
    var scene: Scene!
    
    override func setUp() async throws {
        try Application.prepareForTest()
        
        let scene = Scene()
        self.scene = scene
        scene.readyIfNeeded()
    }
    
    func test_CreateStaticBody() {
        let entity = Entity()
        
        let collision = Collision2DComponent(
            shapes: [.generateBox()],
            mode: .default
        )
        
        entity.components += collision
        entity.components += Transform(position: [0, -10, 0])
        
        scene.addEntity(entity)
        scene.update(1.0 / 60.0)
        
        XCTAssertNotNil(entity.components[Collision2DComponent.self]?.runtimeBody)
        XCTAssertEqual(entity.components[Transform.self]?.position.xy, [0, -10])
    }
    
    func test_DynamicBodyFalling() async {
        // Создаем пол
        let ground = Entity()
        let groundShape = Shape2DResource.generateBox(width: 100, height: 10)
        let groundCollision = Collision2DComponent(shapes: [groundShape], mode: .default)
        ground.components.set(groundCollision)
        ground.components += Transform(position: [0, -10, 0])
        scene.addEntity(ground)
        
        let box = Entity()
        let boxShape = Shape2DResource.generateBox(width: 1, height: 1)
        let boxCollision = PhysicsBody2DComponent(
            shapes: [boxShape],
            mass: 1,
            mode: .dynamic
        )
        box.components += boxCollision
        box.components += Transform(position: [0, 10, 0])
        scene.addEntity(box)
        
        let startY = box.components[Transform.self]?.position.y ?? 0
        
        for _ in 0..<60 {
            scene.update(1.0 / 60.0)
        }
        
        // Проверяем, что объект упал
        let endY = box.components[Transform.self]?.position.y ?? 0
        XCTAssertLessThan(endY, startY)
        XCTAssertGreaterThan(endY, -9) // Не должен пройти сквозь пол
    }
    
    func test_ApplyForce() async {
        let box = Entity()
        let physicsBody = PhysicsBody2DComponent(
            shapes: [.generateBox()],
            mass: 1,
            mode: .dynamic
        )
        box.components += physicsBody
        box.components += Transform(position: .zero)
        scene.addEntity(box)
        
        scene.update(1.0 / 60.0)
        
        box.components[PhysicsBody2DComponent.self]?.applyForceToCenter([100, 0], wake: true)
        
        let initialVelocity = box.components[PhysicsBody2DComponent.self]!.linearVelocity.x
        
        scene.update(1.0 / 60.0)
        
        let finalVelocity = box.components[PhysicsBody2DComponent.self]!.linearVelocity.x
        XCTAssertGreaterThan(finalVelocity, initialVelocity)
    }
    
    func test_Collision() async {
        var collisionOccurred = false
        
        _ = scene.eventManager.subscribe(to: CollisionEvents.Began.self) { event in
            collisionOccurred = true
        }
        
        let entityA = Entity()
        let entityB = Entity()
        
        let boxShape = Shape2DResource.generateBox(width: 1, height: 1)
        
        let collisionA = PhysicsBody2DComponent(
            shapes: [boxShape],
            mode: .static
        )
        
        let collisionB = PhysicsBody2DComponent(
            shapes: [boxShape],
            mode: .static
        )
        
        entityA.components.set(collisionA)
        entityB.components.set(collisionB)
        
        entityA.components += Transform(position: [-1, 0, 0])
        entityB.components += Transform(position: [1, 0, 0])
        
        scene.addEntity(entityA)
        scene.addEntity(entityB)
        
        scene.update(1.0 / 60.0)
        
        entityA.components[Transform.self]?.position.x += 1
        entityB.components[Transform.self]?.position.x -= 1
        
        // Симулируем несколько кадров
        for _ in 0..<10 {
            scene.update(1.0 / 60.0)
        }
        
        XCTAssertTrue(collisionOccurred)
    }
}
