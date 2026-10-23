import AdaECS
@testable import AdaPhysics
import AdaTransform
import Math
import Testing

@MainActor
@Suite(.serialized)
struct Physics2DDebugShapesTests {
    @Test
    func capsuleAndRoundedPolygonOutlinesMatchActualOuterBounds() async throws {
        let fixture = try await PhysicsJoint2DFixture()
        let capsule = try Shape2DResource.generateCapsule(from: [0, -1], to: [0, 1], radius: 0.4)
        fixture.app.main.spawn { Collision2DComponent(shapes: [capsule]); Transform(position: [3, 2, 0]) }
        await fixture.app.main.runScheduler(.physicsSync)
        let world = try #require(fixture.app.main.physicsWorld2D)
        let points = world.collectDebugShapes(options: .showPhysicsShapes).lines.flatMap { [$0.start, $0.end] }
        #expect(abs(try #require(points.map(\.x).min()) - 2.6) < 0.001)
        #expect(abs(try #require(points.map(\.y).max()) - 3.4) < 0.001)
        let other = try await PhysicsJoint2DFixture()
        let rounded = try Shape2DResource.generateRoundedBox(width: 4, height: 2, radius: 0.5)
        other.app.main.spawn { Collision2DComponent(shapes: [rounded]); Transform() }
        await other.app.main.runScheduler(.physicsSync)
        let outline = try #require(other.app.main.physicsWorld2D).collectDebugShapes(options: .showPhysicsShapes).lines.flatMap { [$0.start, $0.end] }
        #expect(abs(try #require(outline.map(\.x).max()) - 2) < 0.001)
        #expect(abs(try #require(outline.map(\.y).max()) - 1) < 0.001)
        #expect(!outline.contains { abs($0.x - 2) < 0.01 && abs($0.y - 1) < 0.01 })
    }

    @Test
    func segmentsChainsAndJointConnectionsReachDebugGeometry() async throws {
        let fixture = try await PhysicsJoint2DFixture()
        let segment = try Shape2DResource.generateSegment(from: [-1, 0], to: [1, 0])
        let chain = try Shape2DResource.generateChain(points: [[2, -1], [0, -2], [-2, -1]])
        fixture.app.main.spawn { Collision2DComponent(shapes: [segment, chain]); Transform() }
        let a = fixture.body(at: [-2, 2], mode: .static)
        let b = fixture.body(at: [2, 2])
        _ = try await fixture.connect(.distance(entityA: a, entityB: b, settings: .init(length: 4)))
        let world = try #require(fixture.app.main.physicsWorld2D)
        let shapes = world.collectDebugShapes(options: .showPhysicsShapes)
        #expect(shapes.lines.contains { $0.start == [-1, 0] && $0.end == [1, 0] })
        #expect(shapes.lines.contains { $0.start == [2, -1] && $0.end == [0, -2] })
        let joints = world.collectDebugShapes(options: .showJoints)
        #expect(joints.lines.contains { abs($0.start.y - 2) < 0.01 && abs($0.end.y - 2) < 0.01 && abs($0.end.x - $0.start.x) > 3 })
        #expect(world.collectDebugShapes(options: []).lines.isEmpty)
    }
}
