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
struct Physics2DConvexShapeTests {
    private func makeWorld() async throws -> AppWorlds {
        let app = AppWorlds(main: World())
        app.addPlugin(MainSchedulerPlugin()).addPlugin(TransformPlugin()).addPlugin(Physics2DPlugin(gravity: .zero))
        try await app.build()
        return app
    }

    private func spawn(_ shape: Shape2DResource, in app: AppWorlds, transform: Transform = Transform(), dynamic: Bool = false) async -> Entity {
        let entity = app.main.spawn {
            if dynamic { PhysicsBody2DComponent(shapes: [shape], mass: 1) } else { Collision2DComponent(shapes: [shape]) }
            transform
        }
        await app.main.runScheduler(.physicsSync)
        return entity
    }

    @Test(arguments: [false, true])
    func capsuleCapsAndOffsetsUseRealNativeGeometry(_ dynamic: Bool) async throws {
        let app = try await makeWorld()
        let shape = try Shape2DResource.generateCapsule(from: [-1, 0], to: [1, 0], radius: 0.5).offsetBy(x: 3, y: 1)
        let entity = await spawn(shape, in: app, transform: Transform(scale: [2, 2, 1]), dynamic: dynamic)
        let physics = try #require(app.main.physicsWorld2D)
        let hit = try #require(physics.raycast(from: [0, 2], to: [12, 2]).first)
        #expect(hit.entity === entity)
        #expect(abs(hit.point.x - 3) < 0.001)
        let cap = try #require(physics.raycast(from: [2, 2.8], to: [6, 2.8]).first)
        #expect(abs(cap.point.x - 3.4) < 0.002)
        #expect(physics.raycast(from: [0, 3.1], to: [12, 3.1]).isEmpty)
        let body = try #require(entity.components[PhysicsBody2DComponent.self]?.runtimeBody ?? entity.components[Collision2DComponent.self]?.runtimeBody)
        #expect(body.getShapes().first?.type == b2_capsuleShape)
    }

    @Test
    func roundedBoxOuterDimensionsAndCornerArcArePreserved() async throws {
        let app = try await makeWorld()
        _ = await spawn(try .generateRoundedBox(width: 4, height: 2, radius: 0.5), in: app)
        let physics = try #require(app.main.physicsWorld2D)
        let middle = try #require(physics.raycast(from: [-3, 0], to: [3, 0]).first)
        #expect(abs(middle.point.x + 2) < 0.001)
        let corner = try #require(physics.raycast(from: [-3, 0.95], to: [3, 0.95]).first)
        #expect(corner.point.x > -1.8 && corner.point.x < -1.6)
        #expect(physics.raycast(from: [-3, 1.01], to: [3, 1.01]).isEmpty)
    }

    @Test
    func roundedBoxLocalRotationAndBodyPoseCompose() async throws {
        let app = try await makeWorld()
        let shape = try Shape2DResource.generateRoundedBox(width: 4, height: 2, radius: 0.5, center: [3, 0], angle: .pi / 2)
        let entity = await spawn(shape, in: app, transform: Transform(position: [10, 0, 0]))
        let hit = try #require(app.main.physicsWorld2D?.raycast(from: [10, 0], to: [16, 0]).first)
        #expect(hit.entity === entity)
        #expect(abs(hit.point.x - 12) < 0.002)
    }

    @Test
    func roundedPolygonRadiusExpandsItsCore() async throws {
        let app = try await makeWorld()
        let shape = try Shape2DResource.generateRoundedPolygon(vertices: [[-1, -1], [1, -1], [0, 1]], radius: 0.25).offsetBy(x: 4, y: 0)
        _ = await spawn(shape, in: app)
        let hit = try #require(app.main.physicsWorld2D?.raycast(from: [0, -1], to: [8, -1]).first)
        #expect(abs(hit.point.x - 2.75) < 0.002)
    }

    @Test
    func nonuniformScaleKeepsCapsCircularUsingLargerAxis() async throws {
        let app = try await makeWorld()
        let shape = try Shape2DResource.generateCapsule(from: [-1, 0], to: [1, 0], radius: 0.5)
        _ = await spawn(shape, in: app, transform: Transform(scale: [2, 1, 1]))
        let hit = try #require(app.main.physicsWorld2D?.raycast(from: [-4, 0.75], to: [4, 0.75]).first)
        #expect(abs(hit.point.x - (-2 - Float(0.4375).squareRoot())) < 0.002)
    }

    @Test
    func newGeometryRoundTripsAndOffsetsAreImmutable() throws {
        let shapes: [Shape2DResource] = [
            try .generateCapsule(from: [0, -1], to: [0, 1], radius: 0.4),
            try .generateRoundedBox(width: 4, height: 2, radius: 0.25, center: [3, 1], angle: 0.4),
            try .generateRoundedPolygon(vertices: [[-1, -1], [1, -1], [0, 1]], radius: 0.2)
        ]
        for shape in shapes {
            let moved = shape.offsetBy(x: 5, y: 2)
            #expect(moved != shape)
            #expect(try JSONDecoder().decode(Shape2DResource.self, from: JSONEncoder().encode(moved)) == moved)
        }
    }

    @Test
    func invalidGeometryIsRejectedBeforeNativeCreation() throws {
        #expect(throws: Shape2DGeometryError.degenerateCapsule) { try Shape2DResource.generateCapsule(from: .zero, to: .zero, radius: 1) }
        #expect(throws: Shape2DGeometryError.degenerateCapsule) { try Shape2DResource.generateCapsule(from: .zero, to: [0.001, 0], radius: 1) }
        #expect(throws: Shape2DGeometryError.invalidRadius) { try Shape2DResource.generateCapsule(from: .zero, to: [0, 1], radius: -1) }
        #expect(throws: Shape2DGeometryError.nonFiniteGeometry) { try Shape2DResource.generateCapsule(from: [.nan, 0], to: [0, 1], radius: 1) }
        #expect(throws: Shape2DGeometryError.invalidRadius) { try Shape2DResource.generateRoundedBox(width: 2, height: 1, radius: 0.5) }
        #expect(throws: Shape2DGeometryError.invalidDimensions) { try Shape2DResource.generateRoundedBox(width: 0, height: 1, radius: 0.1) }
        #expect(throws: Shape2DGeometryError.invalidPolygon) { try Shape2DResource.generateRoundedPolygon(vertices: [[0, 0], [1, 0], [2, 0]], radius: 0.1) }
        #expect(throws: Shape2DGeometryError.invalidPolygon) {
            try Shape2DResource.generateRoundedPolygon(vertices: [[0, 0], [2, 0], [0.5, 0.5], [0, 2]], radius: 0.1)
        }
    }

    @Test
    func decodingCannotBypassGeometryValidation() {
        let data = Data(#"{"fixture":{"capsule":{"_0":{"start":{"x":0,"y":0},"end":{"x":0,"y":1},"radius":-1}}}}"#.utf8)
        #expect(throws: Shape2DGeometryError.invalidRadius) { try JSONDecoder().decode(Shape2DResource.self, from: data) }
    }

    @Test
    func collapsingEntityScaleDoesNotReachNativeHullAssertions() async throws {
        let app = try await makeWorld()
        _ = await spawn(try .generateRoundedBox(width: 2, height: 2, radius: 0.1), in: app, transform: Transform(scale: [0, 0, 1]))
        _ = await spawn(try .generateCapsule(from: [-1, 0], to: [1, 0], radius: 0.2), in: app, transform: Transform(scale: [0, 0, 1]))
        #expect(app.main.physicsWorld2D?.raycast(from: [-3, 0], to: [3, 0]).isEmpty == true)
    }

    @Test
    func capsuleActuallyStopsOnRoundedCollider() async throws {
        let app = try await makeWorld()
        _ = await spawn(try .generateRoundedBox(width: 1, height: 4, radius: 0.2), in: app)
        let entity = await spawn(try .generateCapsule(from: [0, -0.5], to: [0, 0.5], radius: 0.25), in: app, transform: Transform(position: [-3, 0, 0]), dynamic: true)
        entity.components[PhysicsBody2DComponent.self]?.linearVelocity = [5, 0]
        app.main.insertResource(FixedTime(deltaTime: 1.0 / 60))
        for _ in 0..<60 {
            await app.main.runScheduler(.physicsStep)
            await app.main.runScheduler(.physicsWriteback)
        }
        #expect(try #require(entity.components[Transform.self]).position.x < -0.6)
    }
}
