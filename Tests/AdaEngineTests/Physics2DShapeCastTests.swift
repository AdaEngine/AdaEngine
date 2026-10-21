@_spi(Internal) @testable import AdaApp
import AdaECS
@testable import AdaPhysics
import AdaTransform
import Math
import Testing

@MainActor
@Suite(.serialized)
struct Physics2DShapeCastTests {
    private func makeWorld() async throws -> AppWorlds {
        let app = AppWorlds(main: World())
        app.addPlugin(MainSchedulerPlugin()).addPlugin(TransformPlugin()).addPlugin(Physics2DPlugin(gravity: .zero))
        try await app.build()
        return app
    }

    private func wall(_ app: AppWorlds, x: Float, width: Float = 1, sensor: Bool = false, group: CollisionGroup = .default) -> Entity {
        app.main.spawn {
            Collision2DComponent(shapes: [.generateBox(width: width, height: 4)], mode: sensor ? .trigger : .default, filter: CollisionFilter(categoryBitMask: group))
            Transform(position: [x, 0, 0])
        }
    }

    @Test
    func nearestAndAllUsePhysicalTravelDistances() async throws {
        let app = try await makeWorld()
        let far = wall(app, x: 6)
        let near = wall(app, x: 3)
        await app.main.runScheduler(.physicsSync)
        let physics = try #require(app.main.physicsWorld2D)
        let circle = Shape2DResource.generateCircle(radius: 1)
        let all = try physics.shapeCast(circle, from: Transform(), to: [10, 0])
        #expect(all.map(\.entity.id) == [near.id, far.id])
        #expect(abs(try #require(all.first).distance - 2) < 0.02)
        #expect(abs(try #require(all.last).distance - 5) < 0.02)
        #expect(try #require(all.first).normal.x < -0.99)
        #expect(try #require(all.first).fraction < 0.21)
        let first = try physics.shapeCast(circle, from: Transform(), to: [10, 0], query: .first)
        #expect(first.count == 1 && first.first?.entity === near)
        let reversed = try physics.shapeCast(circle, from: Transform(position: [10, 0, 0]), to: [0, 0])
        #expect(reversed.map(\.entity.id) == [far.id, near.id])
    }

    @Test
    func sensorsMasksAndExclusionsDoNotClipTheNearestSolid() async throws {
        let app = try await makeWorld()
        _ = wall(app, x: 2, sensor: true)
        let solid = wall(app, x: 5, group: CollisionGroup(rawValue: 2))
        await app.main.runScheduler(.physicsSync)
        let physics = try #require(app.main.physicsWorld2D)
        let shape = Shape2DResource.generateBox()
        #expect(try physics.shapeCast(shape, from: Transform(), to: [10, 0], query: .first, includeSensors: false).first?.entity === solid)
        #expect(try physics.shapeCast(shape, from: Transform(), to: [10, 0], mask: CollisionGroup(rawValue: 2)).map(\.entity.id) == [solid.id])
        #expect(try physics.shapeCast(shape, from: Transform(), to: [10, 0], includeSensors: false, excluding: [solid.id]).isEmpty)
    }

    @Test
    func initialOverlapsAndZeroMotionAreExplicit() async throws {
        let app = try await makeWorld()
        let target = wall(app, x: 0)
        await app.main.runScheduler(.physicsSync)
        let physics = try #require(app.main.physicsWorld2D)
        let shape = Shape2DResource.generateCircle(radius: 1)
        let hit = try #require(physics.shapeCast(shape, from: Transform(), to: [10, 0]).first)
        #expect(hit.entity === target && hit.isInitialOverlap && hit.distance == 0)
        let stationary = try physics.shapeCast(shape, from: Transform(), to: .zero)
        #expect(stationary.count == 1 && stationary.first?.isInitialOverlap == true)
        #expect(try physics.shapeCast(shape, from: Transform(position: [0, 8, 0]), to: [0, 8]).isEmpty)
    }

    @Test
    func localOffsetsAndCapsulesSweepThroughThinObstacles() async throws {
        let app = try await makeWorld()
        let target = wall(app, x: 4, width: 0.01)
        await app.main.runScheduler(.physicsSync)
        let physics = try #require(app.main.physicsWorld2D)
        let offsetBox = Shape2DResource.generateBox(width: 1, height: 1, center: [1, 0], angle: 0)
        let offset = try #require(physics.shapeCast(offsetBox, from: Transform(), to: [20, 0], query: .first).first)
        #expect(offset.entity === target)
        #expect(abs(offset.distance - 2.495) < 0.02)
        let thinQuery = Shape2DResource.generateBox(width: 0.01, height: 1)
        #expect(try physics.shapeCast(thinQuery, from: Transform(), to: [20, 0]).first?.entity === target)
        #expect(try physics.overlap(thinQuery, at: Transform(position: [4, 0, 0])).first?.entity === target)
        let capsule = try Shape2DResource.generateCapsule(from: [-0.5, 0], to: [0.5, 0], radius: 0.25)
        let hit = try #require(physics.shapeCast(capsule, from: Transform(), to: [20, 0], query: .first).first)
        #expect(hit.entity === target)
        #expect(abs(hit.distance - 3.245) < 0.02)
    }

    @Test
    func chainBackFacesAreIgnoredAndInvalidQueriesThrow() async throws {
        let app = try await makeWorld()
        let chain = try Shape2DResource.generateChain(points: [[2, 0], [-2, 0]])
        app.main.spawn { Collision2DComponent(shapes: [chain]); Transform() }
        await app.main.runScheduler(.physicsSync)
        let physics = try #require(app.main.physicsWorld2D)
        let probe = Shape2DResource.generateCircle(radius: 1)
        #expect(try physics.shapeCast(probe, from: Transform(position: [0, 2, 0]), to: [0, -2]).count == 1)
        #expect(try physics.shapeCast(probe, from: Transform(position: [0, -2, 0]), to: [0, 2]).isEmpty)
        #expect(throws: Physics2DQueryError.unsupportedShape) { try physics.shapeCast(chain, from: Transform(), to: [1, 0]) }
        #expect(throws: Physics2DQueryError.invalidPose) { try physics.shapeCast(probe, from: Transform(), to: [.infinity, 0]) }
        #expect(try physics.shapeCast(probe, from: Transform(), to: [1, 0], mask: []).isEmpty)
    }
}
