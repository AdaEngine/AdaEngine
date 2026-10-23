import AdaECS
@testable import AdaPhysics
import AdaTransform
import Math
import Testing

@MainActor
@Suite(.serialized)
struct Physics2DPreciseQueryTests {
    @Test func thinGeometryUsesNearbyProxiesAndExactGlobalOrigins() async throws {
        let fixture = try await PhysicsJoint2DFixture()
        let physics = try #require(fixture.app.main.physicsWorld2D)
        let origin = PhysicsPosition2D(x: 1e9 + 0.125, y: -1e9 + 0.25)
        #expect(physics.setCoordinateOrigin(origin))
        let target = fixture.app.main.spawn {
            Transform()
            Collision2DComponent(shapes: [.generateBox(width: 0.01, height: 2)])
            PhysicsPosition2DComponent(origin)
        }
        await fixture.app.main.runScheduler(.physicsSync)
        #expect(physics.overlap(at: Vector2.zero).first?.entity === target)
        #expect(physics.overlap(atGlobal: origin).first?.entity === target)
        #expect(physics.overlap(in: Rect(x: -0.1, y: -0.1, width: 0.2, height: 0.2), relativeTo: origin).first?.entity === target)
        let probe = Shape2DResource.generateCircle(radius: 0.2)
        #expect(try physics.overlap(probe, atGlobal: origin).first?.entity === target)
        let hits = try physics.shapeCast(probe, from: origin.offset(by: [-1, 0]), translation: [2, 0], query: .first)
        let hit = try #require(hits.first)
        #expect(hit.entity === target)
        #expect(abs(hit.globalPoint.x - (origin.x - 0.005)) < 0.002)
        #expect(abs(hit.point.x + 0.005) < 0.002)
        #expect(hit.distance > 0.88 && hit.distance < 0.92)
        let local = try #require(physics.shapeCast(probe, from: Transform(position: [-1, 0, 0]), to: [1, 0]).first)
        #expect(abs(local.globalPoint.x - hit.globalPoint.x) < 0.00001)
        #expect(try physics.shapeCast(probe, from: origin, translation: .zero).first?.isInitialOverlap == true)
        #expect(try physics.shapeCast(probe, from: origin, translation: [1, 0], mask: []).isEmpty)
        #expect(physics.overlap(atGlobal: origin, excluding: [target.id]).isEmpty)
        #expect(physics.overlap(atGlobal: PhysicsPosition2D(x: .nan, y: 0)).isEmpty)
        let ray = try #require(physics.raycast(from: [-1, 0], to: [1, 0]).first)
        #expect(abs(ray.globalPoint.x - (origin.x - 0.005)) < 0.00001)
    }

    @Test func globalImpulsePreservesSmallTorqueArm() async throws {
        let fixture = try await PhysicsJoint2DFixture()
        let physics = try #require(fixture.app.main.physicsWorld2D)
        let origin = PhysicsPosition2D(x: 1e9 + 0.125, y: 1e9 + 0.25)
        #expect(physics.setCoordinateOrigin(origin))
        let entity = fixture.body()
        entity.components[PhysicsPosition2DComponent.self] = .init(origin)
        await fixture.app.main.runScheduler(.physicsSync)
        let body = try #require(entity.components[PhysicsBody2DComponent.self])
        #expect(body.preciseWorldCenter == origin)
        #expect(body.applyLinearImpulse([1, 0], atGlobalPoint: origin.offset(by: [0, 0.25]), wake: true))
        #expect(abs(body.angularVelocity + 0.25) < 0.00001)
        #expect(body.linearVelocity == Vector2(1, 0))
        #expect(!body.applyForce(force: [1, 0], atGlobalPoint: .init(x: .infinity, y: 0), wake: true))
    }
}
