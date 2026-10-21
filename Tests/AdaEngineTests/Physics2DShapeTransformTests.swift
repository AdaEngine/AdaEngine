@_spi(Internal) @testable import AdaApp
import AdaECS
@testable import AdaPhysics
import AdaTransform
import Foundation
import Math
import Testing

@MainActor
@Suite(.serialized)
struct Physics2DShapeTransformTests {
    private func makeWorld() async throws -> AppWorlds {
        let app = AppWorlds(main: World())
        app.addPlugin(MainSchedulerPlugin()).addPlugin(TransformPlugin()).addPlugin(Physics2DPlugin(gravity: .zero))
        try await app.build()
        return app
    }

    private func spawn(_ shape: Shape2DResource, in world: World, transform: Transform = Transform(), dynamic: Bool = false) -> Entity {
        world.spawn {
            if dynamic {
                PhysicsBody2DComponent(shapes: [shape], mass: 1)
            } else {
                Collision2DComponent(shapes: [shape])
            }
            transform
        }
    }

    @Test(arguments: [Float(1), -2])
    func thinBoxesSurviveRotationAndMirroredScale(_ scale: Float) async throws {
        let app = try await makeWorld()
        let target = spawn(
            .generateBox(width: 0.01, height: 4, center: [1, 0], angle: .pi / 2),
            in: app.main,
            transform: Transform(scale: [scale, 1, 1], position: [4, 0, 0])
        )
        await app.main.runScheduler(.physicsSync)
        let physics = try #require(app.main.physicsWorld2D)
        let hit = try #require(physics.raycast(from: [4 + scale, 2], to: [4 + scale, -2]).first)
        #expect(hit.entity === target)
        #expect(abs(hit.point.y - 0.005) < 0.001)
    }

    @Test(arguments: [false, true])
    func boxCenterAngleAndScaleAffectNativeGeometry(_ dynamic: Bool) async throws {
        let app = try await makeWorld()
        let shape = Shape2DResource.generateBox(width: 4, height: 1, center: [3, 0], angle: .pi / 2)
        let entity = spawn(shape, in: app.main, transform: Transform(scale: [2, 1, 1], position: [10, 0, 0]), dynamic: dynamic)
        await app.main.runScheduler(.physicsSync)
        let world = try #require(app.main.physicsWorld2D)
        let hit = try #require(world.raycast(from: [12, 0], to: [20, 0]).first)
        // Rotate the 4x1 box, then scale X by two: center=16, half-width=1.
        #expect(hit.entity.id == entity.id)
        #expect(abs(hit.point.x - 15) < 0.001)
        #expect(abs(hit.distance - 3) < 0.001)
        #expect(world.raycast(from: [12, 3], to: [20, 3]).isEmpty)
        #expect(world.raycast(from: [8, 0], to: [12, 0]).isEmpty)
    }

    @Test(arguments: [false, true])
    func entityRotationIsAppliedWhenBodyIsCreated(_ dynamic: Bool) async throws {
        let app = try await makeWorld()
        let shape = Shape2DResource.generateBox(width: 4, height: 1)
        let entity = spawn(shape, in: app.main, transform: Transform(rotation: Quat(axis: [0, 0, 1], angle: .pi / 2)), dynamic: dynamic)
        await app.main.runScheduler(.physicsSync)
        let world = try #require(app.main.physicsWorld2D)
        #expect(world.raycast(from: [-3, 1.5], to: [3, 1.5]).first?.entity.id == entity.id)
        #expect(world.raycast(from: [1.5, -3], to: [1.5, 3]).isEmpty)
    }

    @Test(arguments: [Float(0), 1.5])
    func rotationWritesBackWithTheSameConvention(_ angularVelocity: Float) async throws {
        let app = try await makeWorld()
        let entity = spawn(
            .generateBox(width: 2, height: 1),
            in: app.main,
            transform: Transform(rotation: Quat(axis: [0, 0, 1], angle: 0.4)),
            dynamic: true
        )
        entity.components[PhysicsBody2DComponent.self]?.angularVelocity = angularVelocity
        await app.main.runScheduler(.physicsSync)
        let world = try #require(app.main.physicsWorld2D)
        let body = try #require(entity.components[PhysicsBody2DComponent.self]?.runtimeBody)
        let initialAngle = body.getAngle().radians
        world.updateSimulation(1.0 / 60)
        await app.main.runScheduler(.physicsWriteback)
        let transform = try #require(entity.components[Transform.self])
        #expect(abs(transform.rotation.angle2D.radians - body.getAngle().radians) < 0.00001)
        if angularVelocity == 0 {
            #expect(abs(transform.rotation.angle2D.radians - initialAngle) < 0.00001)
        }
    }

    @Test
    func staticRotationChangesWithoutTranslationAreSynced() async throws {
        let app = try await makeWorld()
        let entity = spawn(.generateBox(width: 4, height: 1), in: app.main)
        await app.main.runScheduler(.physicsSync)
        let world = try #require(app.main.physicsWorld2D)
        #expect(world.raycast(from: [-3, 1.5], to: [3, 1.5]).isEmpty)
        entity.components[Transform.self]?.rotation = Quat(axis: [0, 0, 1], angle: .pi / 2)
        await app.main.runScheduler(.physicsSync)
        #expect(world.raycast(from: [-3, 1.5], to: [3, 1.5]).first?.entity.id == entity.id)
    }

    @Test(arguments: [false, true])
    func circleOffsetScalesWithEntity(_ dynamic: Bool) async throws {
        let app = try await makeWorld()
        // Keep the established factory radius convention in this compatibility slice.
        let shape = Shape2DResource.generateCircle(radius: 2).offsetBy(x: 2, y: 0)
        let entity = spawn(shape, in: app.main, transform: Transform(scale: [2, 2, 1], position: [10, 0, 0]), dynamic: dynamic)
        await app.main.runScheduler(.physicsSync)
        let world = try #require(app.main.physicsWorld2D)
        let hit = try #require(world.raycast(from: [11, 0], to: [18, 0]).first)
        #expect(hit.entity.id == entity.id)
        #expect(abs(hit.point.x - 12) < 0.001)
        #expect(world.raycast(from: [9, -3], to: [9, 3]).isEmpty)
    }

    @Test
    func polygonVerticesAndOffsetUseLocalScale() async throws {
        let app = try await makeWorld()
        let shape = Shape2DResource.generatePolygon(vertices: [[-1, -1], [1, -1], [0, 1]]).offsetBy(x: 2, y: 0)
        let entity = spawn(shape, in: app.main, transform: Transform(scale: [2, 2, 1]))
        await app.main.runScheduler(.physicsSync)
        let hit = try #require(app.main.physicsWorld2D?.raycast(from: [0, -1], to: [8, -1]).first)
        #expect(hit.entity.id == entity.id)
        #expect(abs(hit.point.x - 2.5) < 0.001)
    }

    @Test
    func legacyBoxDecodeDefaultsItsAngleAndPreservesGeometry() throws {
        let data = Data(#"{"fixture":{"box":{"_0":{"halfWidth":2,"halfHeight":0.5,"offset":{"x":3,"y":1}}}}}"#.utf8)
        let shape = try JSONDecoder().decode(Shape2DResource.self, from: data)
        guard case let .box(box) = shape.fixture else {
            Issue.record("Expected legacy box")
            return
        }
        #expect(box.angle == 0)
        #expect(box.offset == [3, 1])
        #expect(box.halfWidth == 2 && box.halfHeight == 0.5)
    }

    @Test
    func boxRotationAndOffsetRoundTrip() throws {
        let shape = Shape2DResource.generateBox(width: 4, height: 1, center: [3, 1], angle: .pi / 3).offsetBy(x: 5, y: 2)
        let decoded = try JSONDecoder().decode(Shape2DResource.self, from: JSONEncoder().encode(shape))
        #expect(decoded == shape)
        guard case let .box(box) = decoded.fixture else {
            Issue.record("Expected box")
            return
        }
        #expect(box.offset == [5, 2])
        #expect(abs(box.angle - .pi / 3) < 0.00001)
    }

    @Test(arguments: [Float.nan, .infinity, -.infinity])
    func nonfiniteBoxAnglesDoNotReachNativeHullCreation(_ angle: Float) async throws {
        let app = try await makeWorld()
        let shape = Shape2DResource.generateBox(width: 2, height: 1, center: .zero, angle: angle)
        let entity = spawn(shape, in: app.main)
        await app.main.runScheduler(.physicsSync)
        #expect(app.main.physicsWorld2D?.raycast(from: [-3, 0], to: [3, 0]).first?.entity.id == entity.id)
    }

    @Test
    func decoderRejectsNonfiniteBoxAngles() {
        let data = Data(#"{"fixture":{"box":{"_0":{"halfWidth":1,"halfHeight":1,"angle":"NaN"}}}}"#.utf8)
        let decoder = JSONDecoder()
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(positiveInfinity: "Infinity", negativeInfinity: "-Infinity", nan: "NaN")
        #expect(throws: DecodingError.self) {
            try decoder.decode(Shape2DResource.self, from: data)
        }
    }

    @Test
    func writebackSkipsMoveEventsForDestroyedBodies() async throws {
        let app = try await makeWorld()
        let entity = spawn(.generateBox(), in: app.main, dynamic: true)
        entity.components[PhysicsBody2DComponent.self]?.linearVelocity = [2, 0]
        await app.main.runScheduler(.physicsSync)
        let world = try #require(app.main.physicsWorld2D)
        world.updateSimulation(1.0 / 60)
        entity.components[PhysicsBody2DComponent.self] = nil
        // Poisoning a stale pointer would crash here without validating the move-event body ID.
        var visited = 0
        world.forEachMovedBody { _, _, _ in visited += 1 }
        #expect(visited == 0)
        await app.main.runScheduler(.physicsWriteback)
    }

    @Test
    func offsetColliderParticipatesInActualContacts() async throws {
        let app = try await makeWorld()
        _ = spawn(.generateBox(width: 1, height: 4).offsetBy(x: 4, y: 0), in: app.main)
        let visitor = spawn(.generateBox(width: 1, height: 1), in: app.main, transform: Transform(position: [2, 0, 0]), dynamic: true)
        visitor.components[PhysicsBody2DComponent.self]?.linearVelocity = [4, 0]
        app.main.insertResource(FixedTime(deltaTime: 1.0 / 60))
        await app.main.runScheduler(.startup)
        for _ in 0..<60 {
            await app.main.runScheduler(.physicsSync)
            await app.main.runScheduler(.physicsStep)
            await app.main.runScheduler(.physicsWriteback)
        }
        #expect(try #require(visitor.components[Transform.self]).position.x < 3.1)
        let events = Events<CollisionEvents.Began>()
        events.update(from: app.main)
        #expect(events.currentEvents.contains { !$0.isSensor })
    }
}
