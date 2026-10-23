//
//  Physics2DTests.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 26.02.2025.
//

@_spi(Internal) @testable import AdaApp
import AdaECS
@testable import AdaPhysics
import AdaTransform
import Testing

@MainActor
@Suite(.serialized)
struct Physics2DTests {
    let world: AppWorlds

    init() async throws {
        let world = AppWorlds(main: World())
        self.world = world

        world
            .addPlugin(MainSchedulerPlugin())
            .addPlugin(Physics2DPlugin())
            .addPlugin(TransformPlugin())
        try await world.build()
    }

    @Test
    func dynamicBodyMoveEventWritesBackTransform() async throws {
        let box = world.main.spawn {
            PhysicsBody2DComponent(
                shapes: [Shape2DResource.generateBox(width: 1, height: 1)],
                mass: 1,
                mode: .dynamic
            )
            Transform(position: [0, 4, 0])
        }

        await world.main.runScheduler(.physicsSync)

        let startY = try #require(box.components[Transform.self]?.position.y)
        let physicsWorld = try #require(world.main.physicsWorld2D)
        physicsWorld.updateSimulation(1.0 / 60.0)
        await world.main.runScheduler(.physicsWriteback)

        let endY = try #require(box.components[Transform.self]?.position.y)
        #expect(endY < startY)
    }

    @Test
    func writebackLeavesTransformAloneWithoutMoveEvent() async throws {
        let box = world.main.spawn {
            PhysicsBody2DComponent(
                shapes: [Shape2DResource.generateBox(width: 1, height: 1)],
                mass: 1,
                mode: .dynamic
            )
            Transform(position: [0, 4, 0])
        }

        await world.main.runScheduler(.physicsSync)
        box.components[Transform.self]?.position.x = 123
        await world.main.runScheduler(.physicsWriteback)

        #expect(box.components[Transform.self]?.position.x == 123)
    }

    @Test(arguments: [1, 4])
    func nativeWorkersCanResolveOverlappingBodies(_ workerCount: Int) async throws {
        let world = AppWorlds(main: World())
        world
            .insertResource(PhysicsSimulationThreading(workerCount: workerCount))
            .addPlugin(MainSchedulerPlugin())
            .addPlugin(Physics2DPlugin())
            .addPlugin(TransformPlugin())
        try await world.build()

        var boxes: [Entity] = []
        for index in 0..<128 {
            let x = Float(index % 16) * 0.75
            let y = Float(index / 16) * 0.75
            boxes.append(world.main.spawn {
                PhysicsBody2DComponent(
                    shapes: [Shape2DResource.generateBox(width: 1, height: 1)],
                    mass: 1,
                    mode: .dynamic
                )
                Transform(position: [x, y, 0])
            })
        }

        await world.main.runScheduler(.physicsSync)
        let physicsWorld = try #require(world.main.physicsWorld2D)
        physicsWorld.updateSimulation(1.0 / 60.0)

        #expect(boxes.allSatisfy { $0.components[PhysicsBody2DComponent.self]?.runtimeBody != nil })
    }

    @Test
    func nativePerformanceProfileReportsStepPhasesAndCounters() throws {
        let metrics = PhysicsPerformanceMetrics()
        let physicsWorld = try #require(world.main.physicsWorld2D)

        physicsWorld.updateSimulation(1.0 / 60.0)
        physicsWorld.recordPerformance(into: metrics)

        let snapshot = try #require(metrics.snapshots.first { $0.dimension == .twoD })
        #expect(snapshot.stepCount == 1)
        #expect(snapshot.step != nil)
        #expect(snapshot.phases.contains { $0.phase == .collide })
        #expect(snapshot.phases.contains { $0.phase == .solve })
        #expect(snapshot.counters.bodyCount >= 0)
    }
    @Test(arguments: [false, true])
    func fixedRotationControlsAngularMotion(_ fixed: Bool) async throws {
        var component = PhysicsBody2DComponent(
            shapes: [.generateBox(width: 1, height: 1)], mass: 1, mode: .dynamic
        )
        component.fixedRotation = fixed
        component.angularVelocity = 2
        let box = world.main.spawn {
            component
            Transform(position: [0, 4, 0])
        }
        await world.main.runScheduler(.physicsSync)
        let physicsWorld = try #require(world.main.physicsWorld2D)
        for _ in 0..<10 {
            physicsWorld.updateSimulation(1.0 / 60.0)
        }
        let body = try #require(box.components[PhysicsBody2DComponent.self]?.runtimeBody)
        if fixed {
            #expect(abs(body.getAngle().radians) < 0.0001)
        } else {
            #expect(body.getAngle().radians > 0.1)
        }
        #expect(body.getPosition().y < 4)
    }

    @Test(arguments: [false, true])
    func preSolveDelegateControlsCollision(_ shouldSolve: Bool) async throws {
        let delegate = CollisionDelegate(shouldSolve: shouldSolve)
        let physicsWorld = try #require(world.main.physicsWorld2D)
        physicsWorld.delegate = delegate
        world.main.spawn {
            Collision2DComponent(shapes: [.generateBox(width: 10, height: 1)])
            Transform()
        }
        let box = world.main.spawn {
            PhysicsBody2DComponent(shapes: [.generateBox(width: 1, height: 1)], mass: 1)
            Transform(position: [0, 2, 0])
        }
        await world.main.runScheduler(.physicsSync)
        for _ in 0..<90 {
            physicsWorld.updateSimulation(1.0 / 60.0)
        }
        let body = try #require(box.components[PhysicsBody2DComponent.self]?.runtimeBody)
        if shouldSolve {
            #expect(body.getPosition().y > 0.9)
        } else {
            #expect(body.getPosition().y < -1)
        }
    }

    @Test
    func customFilterDelegateCanRejectCollision() async throws {
        let delegate = CollisionDelegate(shouldSolve: true, shouldCollide: false)
        let physicsWorld = try #require(world.main.physicsWorld2D)
        physicsWorld.delegate = delegate
        world.main.spawn {
            Collision2DComponent(shapes: [.generateBox(width: 10, height: 1)])
            Transform()
        }
        let box = world.main.spawn {
            PhysicsBody2DComponent(shapes: [.generateBox(width: 1, height: 1)], mass: 1)
            Transform(position: [0, 2, 0])
        }
        await world.main.runScheduler(.physicsSync)
        for _ in 0..<90 {
            physicsWorld.updateSimulation(1.0 / 60.0)
        }
        let body = try #require(box.components[PhysicsBody2DComponent.self]?.runtimeBody)
        #expect(body.getPosition().y < -1)
    }

    private final class CollisionDelegate: PhysicsWorld2DDelegate {
        let shouldSolve: Bool
        let shouldCollide: Bool

        init(shouldSolve: Bool, shouldCollide: Bool = true) {
            self.shouldSolve = shouldSolve
            self.shouldCollide = shouldCollide
        }

        func physicsWorldOnPreSolve(
            _ world: PhysicsWorld2D, entityA: Entity, entityB: Entity, manifold: Manifold2D?
        ) -> Bool {
            shouldSolve
        }

        func physicsWorldOnCustomFilterCalled(
            _ world: PhysicsWorld2D, entityA: Entity, entityB: Entity
        ) -> Bool {
            shouldCollide
        }
    }
//    
//    @Test
//    func createStaticBody() async throws {
//        let entity = world.main.spawn {
//            Collision2DComponent(
//                shapes: [.generateBox()],
//                mode: .default
//            )
//            Transform(position: [0, -10, 0])
//        }
//
//        await world.update()
//        
//        let runtimeBody = try #require(entity.components[Collision2DComponent.self]?.runtimeBody)
//        #expect(runtimeBody.getPosition() == [0, -10])
//    }
//    
//    @Test
//    func dynamicBodyFalling() async {
//        world.main.spawn {
//            Collision2DComponent(
//                shapes: [Shape2DResource.generateBox(width: 100, height: 10)],
//                mode: .default
//            )
//            Transform(position: [0, -10, 0])
//        }
//
//        let box = world.main.spawn {
//            PhysicsBody2DComponent(
//                shapes: [Shape2DResource.generateBox(width: 1, height: 1)],
//                mass: 1,
//                mode: .dynamic
//            )
//            Transform(position: [0, 10, 0])
//        }
//
//        let startY = box.components[Transform.self]?.position.y ?? 0
//        
//        for _ in 0..<60 {
//            await world.update()
//        }
//        
//        let endY = box.components[Transform.self]?.position.y ?? 0
//        #expect(endY < startY)
//        #expect(endY > -9)
//    }
//    
//    @Test
//    func applyForce() async {
//        let box = world.main.spawn {
//            PhysicsBody2DComponent(
//                shapes: [.generateBox()],
//                mass: 1,
//                mode: .dynamic
//            )
//            Transform(position: .zero)
//        }
//        await world.update()
//        box.components[PhysicsBody2DComponent.self]?.applyForceToCenter([100, 0], wake: true)
//        let initialVelocity = box.components[PhysicsBody2DComponent.self]!.linearVelocity.x
//        
//        await world.update()
//        
//        let finalVelocity = box.components[PhysicsBody2DComponent.self]!.linearVelocity.x
//        #expect(finalVelocity > initialVelocity)
//    }
    
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
