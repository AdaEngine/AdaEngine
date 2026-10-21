import AdaECS
@testable import AdaPhysics
import AdaTransform
import box2d
import Foundation
import Math
import Testing

@MainActor
@Suite(.serialized)
struct Physics2DBodyDynamicsTests {
    @Test func dampingDecaysVelocityAndLiveSettingsPreserveBody() async throws {
        let fixture = try await PhysicsJoint2DFixture()
        let entity = fixture.body()
        var settings = PhysicsBody2DDynamics()
        settings.linearDamping = 2; settings.angularDamping = 3; settings.safetyFactor = 0.02; settings.isBullet = true
        try entity.components[PhysicsBody2DComponent.self]?.configureDynamics(settings)
        entity.components[PhysicsBody2DComponent.self]?.linearVelocity = [10, 0]
        entity.components[PhysicsBody2DComponent.self]?.angularVelocity = 4
        await fixture.app.main.runScheduler(.physicsSync)
        let body = try #require(entity.components[PhysicsBody2DComponent.self]?.runtimeBody)
        let id = b2StoreBodyId(body.bodyId)
        #expect(b2Body_IsBullet(body.bodyId))
        #expect(b2Body_GetSafetyFactor(body.bodyId) == 0.02)
        try fixture.step(60)
        #expect(body.getLinearVelocity().x > 1 && body.getLinearVelocity().x < 2)
        #expect(body.getAngularVelocity() > 0.15 && body.getAngularVelocity() < 0.3)
        settings.isBullet = false; settings.linearDamping = 0; settings.angularDamping = 0
        try entity.components[PhysicsBody2DComponent.self]?.configureDynamics(settings)
        #expect(b2StoreBodyId(body.bodyId) == id && !b2Body_IsBullet(body.bodyId))
        #expect(b2Body_GetLinearDamping(body.bodyId) == 0 && b2Body_GetAngularDamping(body.bodyId) == 0)
        let speed = body.getLinearVelocity().x
        try fixture.step(60)
        #expect(abs(body.getLinearVelocity().x - speed) < 0.00001)
    }

    @Test func bulletDoesNotTunnelThroughThinKinematicTarget() async throws {
        let fixture = try await PhysicsJoint2DFixture()
        fixture.app.main.spawn {
            PhysicsBody2DComponent(shapes: [.generateBox(width: 0.02, height: 2)], mode: .kinematic)
            Transform()
        }
        let projectile = fixture.body(at: [-2, 0])
        var dynamics = PhysicsBody2DDynamics()
        dynamics.isBullet = true; dynamics.safetyFactor = 0.01
        try projectile.components[PhysicsBody2DComponent.self]?.configureDynamics(dynamics)
        projectile.components[PhysicsBody2DComponent.self]?.linearVelocity = [120, 0]
        await fixture.app.main.runScheduler(.physicsSync)
        let physics = try #require(fixture.app.main.physicsWorld2D)
        physics.substepIterations = 1
        physics.updateSimulation(1.0 / 30)
        let body = try #require(projectile.components[PhysicsBody2DComponent.self]?.runtimeBody)
        #expect(body.getPosition().x < 0)
        // The box may rotate after impact, so contact response reduces rather than instantly zeros velocity.
        physics.updateSimulation(1.0 / 30)
        #expect(body.getPosition().x < 0)
        #expect(body.getLinearVelocity().x < 120)
    }

    @Test func codecDefaultsAndInvalidSettingsAreAtomic() throws {
        var body = PhysicsBody2DComponent(shapes: [])
        var dynamics = PhysicsBody2DDynamics()
        dynamics.linearDamping = 1; dynamics.isBullet = true
        try body.configureDynamics(dynamics)
        let encoded = try JSONEncoder().encode(body)
        let decoded = try JSONDecoder().decode(PhysicsBody2DComponent.self, from: encoded)
        #expect(decoded.dynamics == dynamics)
        var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "dynamics")
        let legacy = try JSONDecoder().decode(PhysicsBody2DComponent.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(legacy.dynamics == PhysicsBody2DDynamics())
        dynamics.safetyFactor = .nan
        #expect(throws: PhysicsBody2DSettingsError.invalidDynamics) { try body.configureDynamics(dynamics) }
        #expect(body.dynamics == decoded.dynamics)
    }
}
