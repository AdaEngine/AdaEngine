import AdaECS
@testable import AdaPhysics
import box2d
import Foundation
import Math
import Testing

@MainActor
@Suite(.serialized)
struct Physics2DRevoluteJointTests {
    @Test
    func pendulumKeepsItsWorldPivotDuringMotion() async throws {
        let fixture = try await PhysicsJoint2DFixture(gravity: [0, -9.81])
        let bob = fixture.body(at: [1, -2])
        let descriptor = try PhysicsJoint2DDescriptor.revolute(entity: bob, worldAnchor: [1, 0])
        let decoded = try JSONDecoder().decode(PhysicsJoint2DDescriptor.self, from: JSONEncoder().encode(descriptor))
        let joint = try await fixture.connect(decoded)
        bob.components[PhysicsBody2DComponent.self]?.angularVelocity = 1
        let id = try fixture.native(joint)
        var maximumAngle: Float = 0
        var pivotError: Float = 0
        for _ in 0..<180 {
            try fixture.step(1)
            let pivot = b2Body_GetWorldPoint(b2Joint_GetBodyB(id), b2Joint_GetLocalFrameB(id).p)
            pivotError = max(pivotError, abs(pivot.x - 1) + abs(pivot.y))
            maximumAngle = max(maximumAngle, abs(b2RevoluteJoint_GetCurrentAngle(id)))
        }
        #expect(pivotError < 0.02)
        #expect(maximumAngle > 0.1)
    }

    @Test(arguments: [Float(-2), 2])
    func motorsRespectBothAngularLimitsAndBoundTorque(_ speed: Float) async throws {
        let fixture = try await PhysicsJoint2DFixture()
        let a = fixture.body(angle: 0.7, mode: .static)
        let b = fixture.body(angle: 0.7)
        let settings = RevoluteJoint2DSettings(limits: .init(lower: -0.4, upper: 0.6), motor: .init(speed: speed, maximumEffort: 10))
        let joint = try await fixture.connect(.revolute(entityA: a, entityB: b, settings: settings))
        try fixture.step()
        let id = try fixture.native(joint)
        let angle = b2RevoluteJoint_GetCurrentAngle(id)
        #expect(abs(angle - (speed < 0 ? -0.4 : 0.6)) < 0.03)
        #expect(abs(b2RevoluteJoint_GetCurrentMotorTorque(id)) <= 10.01)
    }

    @Test
    func springTargetsAnAngleRelativeToAuthoredFrames() async throws {
        let fixture = try await PhysicsJoint2DFixture()
        let a = fixture.body(mode: .static)
        let b = fixture.body()
        let settings = RevoluteJoint2DSettings(frameA: .init(angle: 0.2), targetAngle: 0.5, spring: .init(hertz: 3))
        let descriptor = try PhysicsJoint2DDescriptor.revolute(entityA: a, entityB: b, settings: settings)
        let decoded = try JSONDecoder().decode(PhysicsJoint2DDescriptor.self, from: JSONEncoder().encode(descriptor))
        let joint = try await fixture.connect(decoded)
        try fixture.step()
        #expect(abs(b2RevoluteJoint_GetCurrentAngle(try fixture.native(joint)) - 0.5) < 0.02)
        #expect(abs(try #require(b.components[PhysicsBody2DComponent.self]?.runtimeBody).getAngle().radians - 0.7) < 0.02)
    }

    @Test
    func legacyOneBodyHingeOwnsAndReleasesItsWorldAnchor() async throws {
        let fixture = try await PhysicsJoint2DFixture()
        let b = fixture.body(at: [3, 4], angle: 0.8)
        let legacy = try JSONDecoder().decode(PhysicsJoint2DDescriptor.self, from: JSONEncoder().encode(PhysicsJoint2DDescriptor.revolute(entityA: b)))
        let joint = try await fixture.connect(legacy)
        let id = try fixture.native(joint)
        let anchor = b2Joint_GetBodyA(id)
        b.components[PhysicsBody2DComponent.self]?.linearVelocity = [10, -5]
        b.components[PhysicsBody2DComponent.self]?.angularVelocity = 1
        try fixture.step(60)
        let position = try #require(b.components[PhysicsBody2DComponent.self]?.runtimeBody).getPosition()
        #expect(abs(position.x - 3) < 0.02 && abs(position.y - 4) < 0.02)
        #expect(abs(b2RevoluteJoint_GetCurrentAngle(id)) > 0.5)
        joint.components.remove(PhysicsJoint2DComponent.self)
        await fixture.app.main.runScheduler(.physicsSync)
        #expect(!b2Joint_IsValid(id) && !b2Body_IsValid(anchor))
    }

    @Test
    func invalidAngularSettingsAreRejected() async throws {
        let fixture = try await PhysicsJoint2DFixture()
        let a = fixture.body(mode: .static)
        let b = fixture.body()
        #expect(throws: PhysicsJoint2DError.invalidSettings) {
            try PhysicsJoint2DDescriptor.revolute(entityA: a, entityB: b, settings: .init(limits: .init(lower: -4, upper: 0)))
        }
        #expect(throws: PhysicsJoint2DError.invalidSettings) { try PhysicsJoint2DDescriptor.revolute(entity: b, worldAnchor: [.nan, 0]) }
        let invalid = PhysicsJoint2DDescriptor(joint: .hinge(a.id, b.id, .init(spring: .init(hertz: -1))))
        let data = try JSONEncoder().encode(invalid)
        #expect(throws: PhysicsJoint2DError.invalidSettings) { try JSONDecoder().decode(PhysicsJoint2DDescriptor.self, from: data) }
    }
}
