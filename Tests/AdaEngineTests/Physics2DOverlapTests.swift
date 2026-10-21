@_spi(Internal) @testable import AdaApp
import AdaECS
@testable import AdaPhysics
import AdaTransform
import Foundation
import Math
import Testing

@MainActor
@Suite(.serialized)
struct Physics2DOverlapTests {
    private func makeWorld() async throws -> AppWorlds {
        let app = AppWorlds(main: World())
        app.addPlugin(MainSchedulerPlugin()).addPlugin(TransformPlugin()).addPlugin(Physics2DPlugin(gravity: .zero))
        try await app.build()
        return app
    }

    @Test
    func pointQueriesHandleEmptyMissBoundaryMasksAndSensors() async throws {
        let app = try await makeWorld()
        let physics = try #require(app.main.physicsWorld2D)
        #expect(physics.overlap(at: .zero).isEmpty)
        let solid = app.main.spawn {
            Collision2DComponent(shapes: [.generateBox(width: 2, height: 2)], filter: CollisionFilter(categoryBitMask: CollisionGroup(rawValue: 2)))
            Transform()
        }
        let sensor = app.main.spawn {
            Collision2DComponent(shapes: [.generateBox(width: 1, height: 1)], mode: .trigger)
            Transform()
        }
        await app.main.runScheduler(.physicsSync)
        let hits = physics.overlap(at: .zero)
        #expect(hits.map(\.entity.id) == [solid.id, sensor.id])
        #expect(hits.filter(\.isSensor).map(\.entity.id) == [sensor.id])
        #expect(physics.overlap(at: .zero, includeSensors: false).map(\.entity.id) == [solid.id])
        #expect(physics.overlap(at: .zero, mask: CollisionGroup(rawValue: 2)).map(\.entity.id) == [solid.id])
        #expect(physics.overlap(at: .zero, excluding: [solid.id, sensor.id]).isEmpty)
        #expect(physics.overlap(at: [1, 0]).map(\.entity.id) == [solid.id])
        #expect(physics.overlap(at: [3, 0]).isEmpty)
        #expect(physics.overlap(at: [.nan, 0]).isEmpty)
        #expect(physics.overlap(at: .zero, mask: []).isEmpty)
    }

    @Test
    func exactShapeOverlapRejectsRoundedCornerAABBCandidate() async throws {
        let app = try await makeWorld()
        let rounded = try Shape2DResource.generateRoundedBox(width: 2, height: 2, radius: 0.5)
        let box = app.main.spawn {
            Collision2DComponent(shapes: [rounded])
            Transform()
        }
        await app.main.runScheduler(.physicsSync)
        let physics = try #require(app.main.physicsWorld2D)
        let bounds = Rect(x: 0.94, y: 0.94, width: 0.02, height: 0.02)
        #expect(physics.overlap(in: bounds).map(\.entity.id) == [box.id])
        let probe = Shape2DResource.generateCircle(radius: 0.02)
        #expect(try physics.overlap(probe, at: Transform(position: [0.95, 0.95, 0])).isEmpty)
        #expect(try physics.overlap(probe, at: Transform()).map(\.entity.id) == [box.id])
    }

    @Test
    func convexQueryPoseIncludesLocalOffsetRotationAndScale() async throws {
        let app = try await makeWorld()
        let target = app.main.spawn {
            Collision2DComponent(shapes: [.generateBox(width: 0.2, height: 0.2)])
            Transform(position: [8, 4, 0])
        }
        await app.main.runScheduler(.physicsSync)
        let physics = try #require(app.main.physicsWorld2D)
        let probe = Shape2DResource.generateBox(width: 4, height: 1, center: [2, 0], angle: .pi / 2)
        let pose = Transform(rotation: Quat(axis: [0, 0, 1], angle: .pi / 2), scale: [2, 1, 1], position: [8, 0, 0])
        #expect(try physics.overlap(probe, at: pose).map(\.entity.id) == [target.id])
        #expect(try physics.overlap(probe, at: Transform()).isEmpty)
    }

    @Test
    func compoundResultsArePerShapeWithStableDistinctIdentifiers() async throws {
        let app = try await makeWorld()
        let target = app.main.spawn {
            Collision2DComponent(shapes: [.generateBox().offsetBy(x: -1, y: 0), .generateBox().offsetBy(x: 1, y: 0)])
            Transform()
        }
        await app.main.runScheduler(.physicsSync)
        let physics = try #require(app.main.physicsWorld2D)
        let hits = try physics.overlap(.generateBox(width: 4, height: 2))
        #expect(hits.count == 2)
        #expect(hits.allSatisfy { $0.entity === target })
        #expect(Set(hits.map(\.shapeID)).count == 2)
        #expect(hits.map(\.shapeID) == hits.map(\.shapeID).sorted())
        #expect(try physics.overlap(.generateBox(width: 4, height: 2), excluding: [target.id]).isEmpty)
    }

    @Test
    func capsuleQueriesAndInvalidGeometryAreHandled() async throws {
        let app = try await makeWorld()
        let target = app.main.spawn {
            Collision2DComponent(shapes: [.generateBox(width: 0.5, height: 0.5)])
            Transform(position: [5.2, 0, 0])
        }
        await app.main.runScheduler(.physicsSync)
        let physics = try #require(app.main.physicsWorld2D)
        let capsule = try Shape2DResource.generateCapsule(from: [-1, 0], to: [1, 0], radius: 0.2)
        #expect(try physics.overlap(capsule, at: Transform(position: [4, 0, 0])).map(\.entity.id) == [target.id])
        let chain = try Shape2DResource.generateChain(points: [[1, 0], [-1, 0]])
        #expect(throws: Physics2DQueryError.unsupportedShape) { try physics.overlap(chain) }
        #expect(throws: Physics2DQueryError.invalidPose) { try physics.overlap(capsule, at: Transform(position: [.nan, 0, 0])) }
        #expect(throws: Physics2DQueryError.invalidGeometry) { try physics.overlap(.generatePolygon(vertices: [])) }
        #expect(throws: Physics2DQueryError.invalidGeometry) { try physics.overlap(.generateBox(), at: Transform(scale: [0, 0, 1])) }
        #expect(physics.overlap(in: Rect(x: 0, y: 0, width: -1, height: 2)).isEmpty)
    }
}
