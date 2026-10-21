import AdaECS
@testable import AdaPhysics
import AdaTransform
import box2d
import Foundation
import Math
import Testing

@MainActor
@Suite(.serialized)
struct Physics2DCoordinateTests {
    @Test func globalPositionSurvivesSimulationAndOriginChanges() async throws {
        let fixture = try await PhysicsJoint2DFixture()
        let physics = try #require(fixture.app.main.physicsWorld2D)
        let origin = PhysicsPosition2D(x: 1e9, y: -1e9)
        #expect(physics.setCoordinateOrigin(origin))
        let body = fixture.body()
        body.components[PhysicsPosition2DComponent.self] = .init(origin.offset(by: [0.125, 0.25]))
        let camera = fixture.app.main.spawn { Transform(); PhysicsPosition2DComponent(origin.offset(by: [2, 3])) }
        await fixture.app.main.runScheduler(.physicsSync)
        let runtime = try #require(body.components[PhysicsBody2DComponent.self]?.runtimeBody)
        let id = b2StoreBodyId(runtime.bodyId)
        #expect(body.components[Transform.self]?.position.xy == Vector2(0.125, 0.25))
        #expect(camera.components[Transform.self]?.position.xy == Vector2(2, 3))
        runtime.setLinearVelocity([0.1, 0])
        physics.updateSimulation(1.0 / 60)
        await fixture.app.main.runScheduler(.physicsWriteback)
        let exact = try #require(body.components[PhysicsPosition2DComponent.self]?.position)
        #expect(exact.x > origin.x + 0.126)
        let nativeBefore = b2Body_GetPosition(runtime.bodyId)
        #expect(physics.setCoordinateOrigin(origin.offset(by: [100, -50])))
        await fixture.app.main.runScheduler(.physicsSync)
        #expect(b2StoreBodyId(runtime.bodyId) == id)
        #expect(PhysicsPosition2D(b2Body_GetPosition(runtime.bodyId)) == PhysicsPosition2D(nativeBefore))
        #expect(camera.components[Transform.self]?.position.xy == Vector2(-98, 53))
        #expect(runtime.getLinearVelocity() == Vector2(0.1, 0))
        let local = try #require(body.components[Transform.self]?.position.xy)
        #expect(physics.raycast(from: local - Vector2(1, 0), to: local + Vector2(1, 0)).first?.entity === body)
        let data = try JSONEncoder().encode(physics)
        #expect(try JSONDecoder().decode(PhysicsWorld2D.self, from: data).coordinateOrigin == physics.coordinateOrigin)
    }

    @Test func staticGlobalTeleportAndInvalidHierarchy() async throws {
        let fixture = try await PhysicsJoint2DFixture()
        let physics = try #require(fixture.app.main.physicsWorld2D)
        let origin = PhysicsPosition2D(x: 1e9, y: 1e9)
        #expect(physics.setCoordinateOrigin(origin))
        let floor = fixture.app.main.spawn {
            Collision2DComponent(shapes: [.generateBox(width: 1, height: 1)])
            Transform()
            PhysicsPosition2DComponent(origin)
        }
        await fixture.app.main.runScheduler(.physicsSync)
        let runtime = try #require(floor.components[Collision2DComponent.self]?.runtimeBody)
        floor.components[PhysicsPosition2DComponent.self]?.position = origin.offset(by: [0.5, 0])
        await fixture.app.main.runScheduler(.physicsSync)
        #expect(PhysicsPosition2D(b2Body_GetPosition(runtime.bodyId)) == origin.offset(by: [0.5, 0]))
        let child = fixture.body()
        child.components[PhysicsPosition2DComponent.self] = .init(origin)
        child.components[RelationshipComponent.self] = .init(parent: floor.id)
        await fixture.app.main.runScheduler(.physicsSync)
        #expect(child.components[PhysicsPosition2DComponent.self]?.lastError == .parentedEntity)
        #expect(child.components[PhysicsBody2DComponent.self]?.runtimeBody == nil)
        #expect(!physics.setCoordinateOrigin(.init(x: .infinity, y: 0)))
    }
}
