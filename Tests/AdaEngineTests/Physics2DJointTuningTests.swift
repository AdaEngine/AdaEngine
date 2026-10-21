import AdaECS
@testable import AdaPhysics
import box2d
import Foundation
import Math
import Testing

@MainActor
@Suite(.serialized)
struct Physics2DJointTuningTests {
    @Test
    func distanceRetuningKeepsIdentityAndPersistsThroughCoding() async throws {
        let fixture = try await PhysicsJoint2DFixture()
        let a = fixture.body(mode: .static)
        let b = fixture.body(at: [2, 0])
        let joint = try await fixture.connect(.distance(entityA: a, entityB: b, settings: .init(length: 2)))
        let old = b2StoreJointId(try fixture.native(joint))
        try fixture.step()
        try joint.components[PhysicsJoint2DComponent.self]?.updateSettings(DistanceJoint2DSettings(length: 1, spring: .init(hertz: 3)))
        await fixture.app.main.runScheduler(.physicsSync)
        #expect(b2StoreJointId(try fixture.native(joint)) == old)
        try fixture.step()
        #expect(abs(b2DistanceJoint_GetCurrentLength(try fixture.native(joint)) - 1) < 0.02)
        let component = try #require(joint.components[PhysicsJoint2DComponent.self])
        let decoded = try JSONDecoder().decode(PhysicsJoint2DComponent.self, from: JSONEncoder().encode(component))
        if case let .distance(_, _, settings) = decoded.jointDescriptor.joint { #expect(settings.length == 1) } else { Issue.record("Expected distance settings") }
    }

    @Test
    func worldHingeRetuningWakesBodyAndKeepsItsReferenceFrame() async throws {
        let fixture = try await PhysicsJoint2DFixture()
        let b = fixture.body(at: [3, 4], angle: 0.8)
        let joint = try await fixture.connect(.revolute(entity: b, worldAnchor: [3, 4]))
        let id = try fixture.native(joint)
        try fixture.step()
        #expect(!b2Body_IsAwake(b2Joint_GetBodyB(id)))
        try joint.components[PhysicsJoint2DComponent.self]?.updateSettings(
            RevoluteJoint2DSettings(limits: .init(lower: -0.6, upper: 0.4), motor: .init(speed: -2, maximumEffort: 10))
        )
        #expect(b2Body_IsAwake(b2Joint_GetBodyB(id)))
        await fixture.app.main.runScheduler(.physicsSync)
        #expect(b2StoreJointId(try fixture.native(joint)) == b2StoreJointId(id))
        try fixture.step()
        #expect(abs(b2RevoluteJoint_GetCurrentAngle(id) + 0.6) < 0.03)
        let position = try #require(b.components[PhysicsBody2DComponent.self]?.runtimeBody).getPosition()
        #expect(abs(position.x - 3) < 0.01 && abs(position.y - 4) < 0.01)
    }

    @Test
    func sliderAndWeldFramesRetuneInPlace() async throws {
        let fixture = try await PhysicsJoint2DFixture()
        let a = fixture.body(mode: .static)
        let slider = fixture.body(at: [2, 0])
        let weld = fixture.body(at: [0, 3])
        let slidingJoint = try await fixture.connect(.prismatic(entityA: a, entityB: slider))
        let weldJoint = try await fixture.connect(.weld(entityA: a, entityB: weld, settings: .init(frameA: .init(position: [0, 3]))))
        let slidingID = try fixture.native(slidingJoint)
        let weldID = try fixture.native(weldJoint)
        try slidingJoint.components[PhysicsJoint2DComponent.self]?.updateSettings(PrismaticJoint2DSettings(targetTranslation: -1, spring: .init(hertz: 3)))
        try weldJoint.components[PhysicsJoint2DComponent.self]?.updateSettings(WeldJoint2DSettings(frameA: .init(position: [0, 4]), linearSpring: .init(hertz: 3)))
        await fixture.app.main.runScheduler(.physicsSync)
        try fixture.step()
        #expect(b2StoreJointId(try fixture.native(slidingJoint)) == b2StoreJointId(slidingID))
        #expect(b2StoreJointId(try fixture.native(weldJoint)) == b2StoreJointId(weldID))
        #expect(abs(b2PrismaticJoint_GetCurrentTranslation(slidingID) + 1) < 0.02)
        #expect(abs(try #require(weld.components[PhysicsBody2DComponent.self]?.runtimeBody).getPosition().y - 4) < 0.02)
    }

    @Test
    func wheelAndMotorControlsReverseExistingBodies() async throws {
        let fixture = try await PhysicsJoint2DFixture(gravity: [0, -10])
        let a = fixture.body(mode: .static)
        let wheel = fixture.body()
        let motor = fixture.body(at: [4, 0])
        motor.components[PhysicsBody2DComponent.self]?.gravityScale = 0
        let wheelJoint = try await fixture.connect(.wheel(entityA: a, entityB: wheel, settings: .init(frameA: .init(angle: .pi / 2))))
        let motorJoint = try await fixture.connect(.motor(entityA: a, entityB: motor))
        let wheelID = try fixture.native(wheelJoint)
        let motorID = try fixture.native(motorJoint)
        try wheelJoint.components[PhysicsJoint2DComponent.self]?.updateSettings(
            WheelJoint2DSettings(frameA: .init(angle: .pi / 2), spring: nil, limits: .init(lower: -0.5, upper: 0.5), motor: .init(speed: -2, maximumEffort: 10))
        )
        try motorJoint.components[PhysicsJoint2DComponent.self]?.updateSettings(
            MotorJoint2DSettings(linearVelocity: [-2, 0], angularVelocity: -2, maximumVelocityForce: 10, maximumVelocityTorque: 10)
        )
        await fixture.app.main.runScheduler(.physicsSync)
        try fixture.step()
        #expect(b2StoreJointId(try fixture.native(wheelJoint)) == b2StoreJointId(wheelID))
        #expect(b2StoreJointId(try fixture.native(motorJoint)) == b2StoreJointId(motorID))
        let wheelBody = try #require(wheel.components[PhysicsBody2DComponent.self]?.runtimeBody)
        #expect(abs(wheelBody.getPosition().y + 0.5) < 0.03 && abs(wheelBody.getAngularVelocity() + 2) < 0.03)
        #expect(abs(try #require(motor.components[PhysicsBody2DComponent.self]?.runtimeBody).getLinearVelocity().x + 2) < 0.03)
    }

    @Test
    func disconnectedWrongKindAndInvalidUpdatesAreSafe() async throws {
        var disconnected = PhysicsJoint2DComponent(joint: PhysicsJoint2DDescriptor(joint: .revolute(1)))
        #expect(throws: PhysicsJoint2DError.notConnected) { try disconnected.updateSettings(DistanceJoint2DSettings(length: 1)) }
        let fixture = try await PhysicsJoint2DFixture()
        let a = fixture.body(mode: .static)
        let b = fixture.body()
        let joint = try await fixture.connect(.revolute(entityA: a, entityB: b))
        #expect(throws: PhysicsJoint2DError.unsupportedControl) { try joint.components[PhysicsJoint2DComponent.self]?.updateSettings(DistanceJoint2DSettings(length: 1)) }
        #expect(throws: PhysicsJoint2DError.invalidSettings) { try joint.components[PhysicsJoint2DComponent.self]?.updateSettings(RevoluteJoint2DSettings(spring: .init(hertz: -1))) }
        joint.components[PhysicsJoint2DComponent.self]?.jointDescriptor = try .revolute(entityA: a, entityB: b)
        #expect(throws: PhysicsJoint2DError.notConnected) { try joint.components[PhysicsJoint2DComponent.self]?.updateSettings(RevoluteJoint2DSettings()) }
    }
}
