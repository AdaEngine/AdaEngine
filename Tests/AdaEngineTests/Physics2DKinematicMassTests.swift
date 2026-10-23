import AdaECS
@testable import AdaPhysics
import box2d
import Testing

@MainActor
@Suite(.serialized)
struct Physics2DKinematicMassTests {
    @Test
    func authoredMassDoesNotMakeKinematicBodiesFall() async throws {
        let fixture = try await PhysicsJoint2DFixture(gravity: [0, -10])
        let entity = fixture.body(at: [0, 3], mode: .kinematic)
        entity.components[PhysicsBody2DComponent.self]?.linearVelocity = [2, 0]
        await fixture.app.main.runScheduler(.physicsSync)
        let body = try #require(entity.components[PhysicsBody2DComponent.self]?.runtimeBody)
        #expect(b2Body_GetType(body.bodyId) == b2_kinematicBody && body.massData.mass == 0)
        try fixture.step(120)
        #expect(abs(body.getPosition().x - 4) < 0.01 && abs(body.getPosition().y - 3) < 0.01)
    }
}
