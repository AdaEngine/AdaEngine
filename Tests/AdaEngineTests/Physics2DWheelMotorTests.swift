import AdaECS
@testable import AdaPhysics
import box2d
import Foundation
import Math
import Testing

@MainActor
@Suite(.serialized)
struct Physics2DWheelMotorTests {
    @Test
    func suspensionCompressesUnderGravityWhileWheelMotorTurns() async throws {
        let fixture = try await PhysicsJoint2DFixture(gravity: [0, -10])
        let a = fixture.body(mode: .static)
        let b = fixture.body(at: [0, -0.5])
        let settings = WheelJoint2DSettings(frameA: .init(angle: .pi / 2), motor: .init(speed: 2, maximumEffort: 4))
        let descriptor = try PhysicsJoint2DDescriptor.wheel(entityA: a, entityB: b, settings: settings)
        let decoded = try JSONDecoder().decode(PhysicsJoint2DDescriptor.self, from: JSONEncoder().encode(descriptor))
        let joint = try await fixture.connect(decoded)
        try fixture.step()
        let id = try fixture.native(joint)
        let body = try #require(b.components[PhysicsBody2DComponent.self]?.runtimeBody)
        let compression = body.getPosition().y
        #expect(compression < 0 && compression > -0.1)
        #expect(abs(body.getAngularVelocity() - 2) < 0.03)
        #expect(abs(b2WheelJoint_GetCurrentMotorTorque(id)) <= 4.01)
    }

    @Test
    func suspensionTravelLimitsHoldWithoutASpring() async throws {
        let fixture = try await PhysicsJoint2DFixture(gravity: [0, -10])
        let a = fixture.body(mode: .static)
        let b = fixture.body()
        let settings = WheelJoint2DSettings(frameA: .init(angle: .pi / 2), spring: nil, limits: .init(lower: -0.5, upper: 0.5))
        let joint = try await fixture.connect(.wheel(entityA: a, entityB: b, settings: settings))
        try fixture.step()
        #expect(b2Joint_IsValid(try fixture.native(joint)))
        let position = try #require(b.components[PhysicsBody2DComponent.self]?.runtimeBody).getPosition()
        #expect(abs(position.y + 0.5) < 0.03 && abs(position.x) < 0.01)
    }

    @Test
    func motorVelocityTargetsRespectForceAndTorqueCaps() async throws {
        let fixture = try await PhysicsJoint2DFixture()
        let a = fixture.body(mode: .static)
        let b = fixture.body()
        let settings = MotorJoint2DSettings(linearVelocity: [4, 0], angularVelocity: 5, maximumVelocityForce: 2, maximumVelocityTorque: 1)
        let joint = try await fixture.connect(.motor(entityA: a, entityB: b, settings: settings))
        try fixture.step(60)
        let body = try #require(b.components[PhysicsBody2DComponent.self]?.runtimeBody)
        #expect(body.getLinearVelocity().x > 1.8 && body.getLinearVelocity().x < 2.1)
        #expect(body.getAngularVelocity() > 0.9 && body.getAngularVelocity() < 1.1)
        let id = try fixture.native(joint)
        #expect(abs(b2Joint_GetConstraintForce(id).x) <= 2.01)
        #expect(abs(b2Joint_GetConstraintTorque(id)) <= 1.01)
    }

    @Test
    func boundedPoseServosConvergeToAuthoredFrames() async throws {
        let fixture = try await PhysicsJoint2DFixture()
        let a = fixture.body(mode: .static)
        let b = fixture.body()
        let settings = MotorJoint2DSettings(frameA: .init(position: [2, 0], angle: 0.5), linearSpring: .init(hertz: 3), angularSpring: .init(hertz: 3))
        let descriptor = try PhysicsJoint2DDescriptor.motor(entityA: a, entityB: b, settings: settings)
        let decoded = try JSONDecoder().decode(PhysicsJoint2DDescriptor.self, from: JSONEncoder().encode(descriptor))
        _ = try await fixture.connect(decoded)
        try fixture.step()
        let body = try #require(b.components[PhysicsBody2DComponent.self]?.runtimeBody)
        #expect(abs(body.getPosition().x - 2) < 0.02)
        #expect(abs(body.getAngle().radians - 0.5) < 0.02)
    }

    @Test
    func invalidMotorBoundsAndSuspensionSettingsAreRejected() async throws {
        let fixture = try await PhysicsJoint2DFixture()
        let a = fixture.body(mode: .static)
        let b = fixture.body()
        #expect(throws: PhysicsJoint2DError.invalidSettings) {
            try PhysicsJoint2DDescriptor.motor(entityA: a, entityB: b, settings: .init(maximumVelocityForce: -1))
        }
        #expect(throws: PhysicsJoint2DError.invalidSettings) {
            try PhysicsJoint2DDescriptor.wheel(entityA: a, entityB: b, settings: .init(spring: .init(hertz: -1)))
        }
    }
}
