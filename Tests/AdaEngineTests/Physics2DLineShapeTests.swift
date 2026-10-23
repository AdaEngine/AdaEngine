@_spi(Internal) @testable import AdaApp
import AdaECS
@testable import AdaPhysics
import AdaTransform
import box2d
import Foundation
import Math
import Testing

@MainActor
@Suite(.serialized)
struct Physics2DLineShapeTests {
    private func makeWorld() async throws -> AppWorlds {
        let app = AppWorlds(main: World())
        app.addPlugin(MainSchedulerPlugin()).addPlugin(TransformPlugin()).addPlugin(Physics2DPlugin(gravity: .zero))
        try await app.build()
        app.main.insertResource(FixedTime(deltaTime: 1.0 / 60))
        await app.main.runScheduler(.startup)
        return app
    }

    private func spawn(_ shape: Shape2DResource, in app: AppWorlds, transform: Transform = Transform(), sensor: Bool = false) async -> Entity {
        let entity = app.main.spawn {
            Collision2DComponent(shapes: [shape], mode: sensor ? .trigger : .default)
            transform
        }
        await app.main.runScheduler(.physicsSync)
        return entity
    }

    @Test
    func segmentsAreTwoSidedAndRespectOffsets() async throws {
        let app = try await makeWorld()
        let shape = try Shape2DResource.generateSegment(from: [-2, 0], to: [2, 0]).offsetBy(x: 3, y: 1)
        let entity = await spawn(shape, in: app)
        let physics = try #require(app.main.physicsWorld2D)
        #expect(physics.raycast(from: [3, 3], to: [3, -1]).first?.entity === entity)
        #expect(physics.raycast(from: [3, -1], to: [3, 3]).first?.entity === entity)
        #expect(physics.raycast(from: [0, 3], to: [0, -1]).isEmpty)
    }

    @Test(arguments: [false, true])
    func openChainsAndLooseSegmentsAreOneSidedEvenWhenMirrored(_ loose: Bool) async throws {
        let app = try await makeWorld()
        let shape = loose ? try Shape2DResource.generateChainSegment(from: [2, 0], to: [-2, 0])
            : try Shape2DResource.generateChain(points: [[2, 0], [-2, 0]])
        let entity = await spawn(shape, in: app, transform: Transform(scale: [-1, 1, 1]))
        let physics = try #require(app.main.physicsWorld2D)
        #expect(physics.raycast(from: [0, 2], to: [0, -2]).first?.entity === entity)
        #expect(physics.raycast(from: [0, -2], to: [0, 2]).isEmpty)
    }

    @Test
    func closedChainsOwnEverySegmentAndAreFreedWithTheBody() async throws {
        let app = try await makeWorld()
        let shape = try Shape2DResource.generateChain(points: [[-2, -2], [2, -2], [2, 2], [-2, 2]], isLoop: true)
        let entity = await spawn(shape, in: app)
        let bodyID = try #require(entity.components[Collision2DComponent.self]?.runtimeBody?.bodyId)
        #expect(b2Body_GetShapeCount(bodyID) == 4)
        let physics = try #require(app.main.physicsWorld2D)
        #expect(physics.raycast(from: [-4, 0], to: [4, 0]).count == 1)
        var first = b2_nullShapeId
        _ = unsafe b2Body_GetShapes(bodyID, &first, 1)
        let chain = b2Shape_GetParentChain(first)
        #expect(b2Chain_IsValid(chain))
        entity.components[Collision2DComponent.self] = nil
        #expect(!b2Chain_IsValid(chain))
    }

    @Test
    func ballSlidesAcrossAnOpenChainSeam() async throws {
        let app = try await makeWorld()
        _ = await spawn(try .generateChain(points: [[4, 0], [0, 0], [-4, 0]]), in: app)
        let physics = try #require(app.main.physicsWorld2D)
        physics.gravity = [0, -9.81]
        let ball = app.main.spawn {
            PhysicsBody2DComponent(shapes: [.generateCircle(radius: 1)], mass: 1, material: .generate(friction: 0, restitution: 0, density: 1))
            Transform(position: [-2, 1.5, 0])
        }
        ball.components[PhysicsBody2DComponent.self]?.linearVelocity = [2, 0]
        await app.main.runScheduler(.physicsSync)
        for _ in 0..<120 {
            await app.main.runScheduler(.physicsStep)
            await app.main.runScheduler(.physicsWriteback)
        }
        let position = try #require(ball.components[Transform.self]?.position)
        #expect(position.x > 1.8)
        #expect(position.y > 0.4 && position.y < 0.7)
    }

    @Test
    func chainCanBeDetectedAsASensor() async throws {
        let app = try await makeWorld()
        _ = await spawn(try .generateChain(points: [[2, 0], [-2, 0]]), in: app, sensor: true)
        let visitor = app.main.spawn {
            PhysicsBody2DComponent(shapes: [.generateBox(width: 1, height: 1)], mass: 1)
            Transform()
        }
        await app.main.runScheduler(.physicsSync)
        await app.main.runScheduler(.physicsStep)
        let events = Events<CollisionEvents.Began>()
        events.update(from: app.main)
        #expect(events.currentEvents.contains { $0.isSensor && $0.entityB === visitor })
    }

    @Test
    func ownedChainsPropagateMaterialsFiltersAndEventFlags() async throws {
        let app = try await makeWorld()
        var component = PhysicsBody2DComponent(
            shapes: [try .generateChain(points: [[2, 0], [0, 0], [-2, 0]])],
            mass: 1,
            material: .generate(friction: 0.2, restitution: 0.3, density: 1),
            mode: .static
        )
        component.filter = CollisionFilter(categoryBitMask: CollisionGroup(rawValue: 2))
        let entity = app.main.spawn { component; Transform() }
        await app.main.runScheduler(.physicsSync)
        let body = try #require(entity.components[PhysicsBody2DComponent.self]?.runtimeBody)
        var ids = [b2ShapeId](repeating: b2_nullShapeId, count: Int(body.shapesCount))
        _ = unsafe ids.withUnsafeMutableBufferPointer { unsafe b2Body_GetShapes(body.bodyId, $0.baseAddress, Int32($0.count)) }
        #expect(ids.count == 2)
        for id in ids {
            #expect(b2Shape_GetFilter(id).categoryBits == 2)
            #expect(abs(b2Shape_GetSurfaceMaterial(id).friction - 0.2) < 0.00001)
            #expect(b2Shape_AreContactEventsEnabled(id) && b2Shape_AreHitEventsEnabled(id))
        }
        let physics = try #require(app.main.physicsWorld2D)
        #expect(physics.raycast(from: [1, 1], to: [1, -1], mask: .default).isEmpty)
        #expect(physics.raycast(from: [1, 1], to: [1, -1], mask: CollisionGroup(rawValue: 2)).count == 1)
    }

    @Test
    func lineResourcesRoundTripAndRejectMalformedData() throws {
        let shapes: [Shape2DResource] = [
            try .generateSegment(from: [-1, 0], to: [1, 0]),
            try .generateChainSegment(from: [1, 0], to: [-1, 0], ghostStart: [2, 1], ghostEnd: [-2, 1]),
            try .generateChain(points: [[2, 0], [0, 0], [-2, 1]])
        ]
        for shape in shapes {
            let shifted = shape.offsetBy(x: 3, y: 4)
            #expect(try JSONDecoder().decode(Shape2DResource.self, from: JSONEncoder().encode(shifted)) == shifted)
        }
        #expect(throws: Shape2DGeometryError.invalidChain) { try Shape2DResource.generateSegment(from: .zero, to: .zero) }
        #expect(throws: Shape2DGeometryError.invalidChain) { try Shape2DResource.generateChain(points: [[0, 0]]) }
        #expect(throws: Shape2DGeometryError.invalidChain) {
            try Shape2DResource.generateChain(points: [[-1, -1], [1, 1], [-1, 1], [1, -1]])
        }
        let invalid = Data(#"{"fixture":{"chain":{"_0":{"points":[{"x":0,"y":0}]}}}}"#.utf8)
        #expect(throws: Shape2DGeometryError.invalidChain) { try JSONDecoder().decode(Shape2DResource.self, from: invalid) }
    }
}
