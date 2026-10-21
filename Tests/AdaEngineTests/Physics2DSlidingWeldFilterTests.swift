import AdaECS
@testable import AdaPhysics
import box2d
import Foundation
import Math
import Testing

@MainActor
@Suite(.serialized)
struct Physics2DSlidingWeldFilterTests {
    @Test(arguments: [Float(-2), 2])
    func sliderFollowsRotatedAxisAndStopsAtBothLimits(_ speed: Float) async throws {
        let fixture = try await PhysicsJoint2DFixture()
        let a = fixture.body(mode: .static)
        let b = fixture.body()
        let settings = PrismaticJoint2DSettings(
            frameA: .init(angle: .pi / 2),
            frameB: .init(angle: .pi / 2),
            limits: .init(lower: -1, upper: 1.5),
            motor: .init(speed: speed, maximumEffort: 10)
        )
        let joint = try await fixture.connect(.prismatic(entityA: a, entityB: b, settings: settings))
        try fixture.step()
        let id = try fixture.native(joint)
        #expect(abs(b2PrismaticJoint_GetCurrentTranslation(id) - (speed < 0 ? -1 : 1.5)) < 0.03)
        let body = try #require(b.components[PhysicsBody2DComponent.self]?.runtimeBody)
        #expect(abs(body.getPosition().x) < 0.01 && abs(body.getAngle().radians) < 0.01)
        #expect(abs(b2PrismaticJoint_GetCurrentMotorForce(id)) <= 10.01)
    }

    @Test
    func sliderSpringConvergesToItsTarget() async throws {
        let fixture = try await PhysicsJoint2DFixture()
        let a = fixture.body(mode: .static)
        let b = fixture.body(at: [3, 0])
        let descriptor = try PhysicsJoint2DDescriptor.prismatic(entityA: a, entityB: b, settings: .init(targetTranslation: 1, spring: .init(hertz: 3)))
        let decoded = try JSONDecoder().decode(PhysicsJoint2DDescriptor.self, from: JSONEncoder().encode(descriptor))
        let joint = try await fixture.connect(decoded)
        try fixture.step()
        #expect(abs(b2PrismaticJoint_GetCurrentTranslation(try fixture.native(joint)) - 1) < 0.02)
    }

    @Test(arguments: [false, true])
    func rigidAndSoftWeldsHoldRelativePose(_ soft: Bool) async throws {
        let fixture = try await PhysicsJoint2DFixture()
        let a = fixture.body(mode: .static)
        let b = fixture.body(at: [2, 0], angle: 0.4)
        let spring: JointSpring2D? = soft ? .init(hertz: 3) : nil
        let settings = WeldJoint2DSettings(frameA: .init(position: [2, 0], angle: 0.4), linearSpring: spring, angularSpring: spring)
        let descriptor = try PhysicsJoint2DDescriptor.weld(entityA: a, entityB: b, settings: settings)
        let decoded = try JSONDecoder().decode(PhysicsJoint2DDescriptor.self, from: JSONEncoder().encode(descriptor))
        _ = try await fixture.connect(decoded)
        b.components[PhysicsBody2DComponent.self]?.linearVelocity = [4, 3]
        b.components[PhysicsBody2DComponent.self]?.angularVelocity = 2
        try fixture.step()
        let body = try #require(b.components[PhysicsBody2DComponent.self]?.runtimeBody)
        #expect(abs(body.getPosition().x - 2) < 0.02 && abs(body.getPosition().y) < 0.02)
        #expect(abs(body.getAngle().radians - 0.4) < 0.02)
    }

    @Test
    func filterSuppressesAndRestoresPairCollisionWithoutRestrictingMotion() async throws {
        let fixture = try await PhysicsJoint2DFixture()
        let a = fixture.body()
        let b = fixture.body()
        let descriptor = try PhysicsJoint2DDescriptor.filter(entityA: a, entityB: b)
        let decoded = try JSONDecoder().decode(PhysicsJoint2DDescriptor.self, from: JSONEncoder().encode(descriptor))
        let joint = try await fixture.connect(decoded)
        try fixture.step(30)
        let bodyA = try #require(a.components[PhysicsBody2DComponent.self]?.runtimeBody)
        let bodyB = try #require(b.components[PhysicsBody2DComponent.self]?.runtimeBody)
        #expect((bodyB.getPosition() - bodyA.getPosition()).squaredLength < 0.001)
        joint.components.remove(PhysicsJoint2DComponent.self)
        await fixture.app.main.runScheduler(.physicsSync)
        try fixture.step(60)
        #expect((bodyB.getPosition() - bodyA.getPosition()).squaredLength > 0.2)
    }

    @Test
    func invalidSettingsFailBeforeNativeCreation() async throws {
        let fixture = try await PhysicsJoint2DFixture()
        let a = fixture.body(mode: .static)
        let b = fixture.body()
        #expect(throws: PhysicsJoint2DError.invalidSettings) {
            try PhysicsJoint2DDescriptor.prismatic(entityA: a, entityB: b, settings: .init(limits: .init(lower: 2, upper: 1)))
        }
        #expect(throws: PhysicsJoint2DError.invalidSettings) {
            try PhysicsJoint2DDescriptor.weld(entityA: a, entityB: b, settings: .init(angularSpring: .init(hertz: -1)))
        }
    }
}
