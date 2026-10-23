import AdaECS
@testable import AdaPhysics
import AdaTransform
import box2d
import Math
import Testing

@MainActor
@Suite(.serialized)
struct Physics2DContactSnapshotTests {
    @Test func pointsImpulsesAndIdentitySurviveRebaseButExpireAfterRemoval() async throws {
        let fixture = try await PhysicsJoint2DFixture(gravity: [0, -10])
        let physics = try #require(fixture.app.main.physicsWorld2D)
        let origin = PhysicsPosition2D(x: 1e9 + 0.125, y: 1e9 + 0.25)
        #expect(physics.setCoordinateOrigin(origin))
        let floor = fixture.app.main.spawn {
            Collision2DComponent(shapes: [.generateBox(width: 20, height: 1)])
            Transform()
            PhysicsPosition2DComponent(origin.offset(by: [0, -0.5]))
        }
        let box = fixture.body()
        box.components[PhysicsPosition2DComponent.self] = .init(origin.offset(by: [0, 0.5]))
        await fixture.app.main.runScheduler(.physicsSync)
        try fixture.step(10)
        await fixture.app.main.runScheduler(.physicsWriteback)
        let snapshot = try #require(physics.contacts(for: box).first)
        #expect(physics.isValid(snapshot.id) && snapshot.manifold.phase == .postSolve)
        #expect(snapshot.manifold.points.count == 2)
        #expect(abs(snapshot.manifold.normal.y) > 0.99)
        #expect(snapshot.manifold.points.allSatisfy { $0.totalNormalImpulse > 0 && abs($0.separation) < 0.05 && $0.normalVelocity != nil })
        #expect(Set(snapshot.manifold.points.map(\.id)).count == 2)
        #expect(snapshot.manifold.points.allSatisfy { abs($0.globalPoint.y - origin.y) < 0.05 && abs($0.point.x) < 1 })
        #expect(physics.contacts(forShape: snapshot.shapeA).contains { $0.id == snapshot.id })
        #expect(physics.setCoordinateOrigin(origin.offset(by: [100, -50])))
        await fixture.app.main.runScheduler(.physicsSync)
        #expect(physics.contacts(for: box).first?.id == snapshot.id)
        #expect(physics.contactSnapshot(for: snapshot.id)?.manifold.points.count == 2)
        let foreign = try await PhysicsJoint2DFixture()
        let other = try #require(foreign.app.main.physicsWorld2D)
        #expect(!other.isValid(snapshot.id) && other.contactSnapshot(for: snapshot.id) == nil)
        #expect(other.contacts(for: floor).isEmpty && other.contacts(forShape: snapshot.shapeA).isEmpty)
        physics.destroyBody(try #require(box.components[PhysicsBody2DComponent.self]?.runtimeBody))
        box.components.remove(PhysicsBody2DComponent.self)
        #expect(!physics.isValid(snapshot.id) && physics.contactSnapshot(for: snapshot.id) == nil)
        #expect(snapshot.manifold.points.count == 2 && snapshot.manifold.points[0].totalNormalImpulse > 0)
    }

    @Test func disabledHitReportingMakesNormalVelocityUnavailable() async throws {
        let fixture = try await PhysicsJoint2DFixture(gravity: [0, -10])
        let floor = fixture.app.main.spawn { Collision2DComponent(shapes: [.generateBox(width: 10, height: 1)]); Transform(position: [0, -0.5, 0]) }
        let box = fixture.body(at: [0, 0.5])
        await fixture.app.main.runScheduler(.physicsSync)
        try fixture.step(10)
        let physics = try #require(fixture.app.main.physicsWorld2D)
        b2Body_EnableHitEvents(try #require(box.components[PhysicsBody2DComponent.self]?.runtimeBody).bodyId, false)
        b2Body_EnableHitEvents(try #require(floor.components[Collision2DComponent.self]?.runtimeBody).bodyId, false)
        let snapshot = try #require(physics.contacts(for: box).first)
        #expect(!snapshot.manifold.points.isEmpty && snapshot.manifold.points.allSatisfy { $0.normalVelocity == nil })
    }

    @Test func sensorsDoNotInventSolverManifolds() async throws {
        let fixture = try await PhysicsJoint2DFixture()
        let sensor = fixture.app.main.spawn { Collision2DComponent(shapes: [.generateBox(width: 4, height: 4)], mode: .trigger); Transform() }
        _ = fixture.body()
        await fixture.app.main.runScheduler(.physicsSync)
        try fixture.step(1)
        #expect(try #require(fixture.app.main.physicsWorld2D).contacts(for: sensor).isEmpty)
    }
}
