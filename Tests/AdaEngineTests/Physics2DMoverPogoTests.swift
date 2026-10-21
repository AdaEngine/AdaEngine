import AdaECS
@testable import AdaPhysics
import box2d
import Foundation
import Math
import Testing

@MainActor
@Suite(.serialized)
struct Physics2DMoverPogoTests {
    @Test
    func moverBoundsAxesRetunesAndLeavesRotationFree() async throws {
        let fixture = try await PhysicsJoint2DFixture()
        let a = fixture.body(mode: .static)
        let b = fixture.body()
        b.components[PhysicsBody2DComponent.self]?.angularVelocity = 1
        let settings = MoverJoint2DSettings(linearVelocity: [4, 0], maximumVelocityForce: [2, 0], collideConnected: false)
        let descriptor = try PhysicsJoint2DDescriptor.mover(entityA: a, entityB: b, settings: settings)
        let decoded = try JSONDecoder().decode(PhysicsJoint2DDescriptor.self, from: JSONEncoder().encode(descriptor))
        let joint = try await fixture.connect(decoded)
        let id = try fixture.native(joint)
        try fixture.step(60)
        let body = try #require(b.components[PhysicsBody2DComponent.self]?.runtimeBody)
        #expect(abs(body.getLinearVelocity().x - 2) < 0.03)
        #expect(abs(body.getAngularVelocity() - 1) < 0.03)
        #expect(abs(b2Joint_GetConstraintForce(id).x) <= 2.01)
        try joint.components[PhysicsJoint2DComponent.self]?.updateSettings(MoverJoint2DSettings(linearVelocity: [-3, 0], maximumVelocityForce: [10, 0], collideConnected: false))
        await fixture.app.main.runScheduler(.physicsSync)
        try fixture.step(60)
        #expect(abs(body.getLinearVelocity().x + 3) < 0.03)
        #expect(b2StoreJointId(try fixture.native(joint)) == b2StoreJointId(id))
    }

    @Test(arguments: [false, true])
    func pogoSupportsWeightWithNormalizedNormalAndRetunesSpring(_ horizontal: Bool) async throws {
        let axis: Vector2 = horizontal ? [1, 0] : [0, 1]
        let fixture = try await PhysicsJoint2DFixture(gravity: axis * -10)
        let a = fixture.body(mode: .static)
        let b = fixture.body(at: axis)
        let settings = PogoJoint2DSettings(frameB: .init(angle: horizontal ? -.pi / 2 : 0), normal: axis * 2, restLength: 2, collideConnected: false)
        let descriptor = try PhysicsJoint2DDescriptor.pogo(entityA: a, entityB: b, settings: settings)
        let decoded = try JSONDecoder().decode(PhysicsJoint2DDescriptor.self, from: JSONEncoder().encode(descriptor))
        let joint = try await fixture.connect(decoded)
        let id = try fixture.native(joint)
        let body = try #require(b.components[PhysicsBody2DComponent.self]?.runtimeBody)
        // Pogo's position correction deliberately avoids adding body velocity. Keep this active
        // drive awake while testing target convergence; dynamic character movers do the same.
        b2Body_EnableSleeping(body.bodyId, false)
        try fixture.step()
        var position = body.getPosition()
        #expect(abs(position.x * axis.x + position.y * axis.y - 2) < 0.05)
        try joint.components[PhysicsJoint2DComponent.self]?.updatePogoSpring(.init(hertz: 5), restLength: 3)
        await fixture.app.main.runScheduler(.physicsSync)
        try fixture.step()
        position = body.getPosition()
        #expect(abs(position.x * axis.x + position.y * axis.y - 3) < 0.05)
        #expect(b2StoreJointId(try fixture.native(joint)) == b2StoreJointId(id))
    }

    @Test
    func pogoCannotSupportWeightBeyondCompressionCap() async throws {
        let fixture = try await PhysicsJoint2DFixture(gravity: [0, -100])
        let a = fixture.body(mode: .static)
        let b = fixture.body(at: [0, 2])
        let settings = PogoJoint2DSettings(restLength: 2, maximumCompressionForce: 10, collideConnected: false)
        let joint = try await fixture.connect(.pogo(entityA: a, entityB: b, settings: settings))
        try fixture.step(60)
        #expect(try #require(b.components[PhysicsBody2DComponent.self]?.runtimeBody).getPosition().y < 0.5)
        #expect(abs(b2Joint_GetConstraintForce(try fixture.native(joint)).y) <= 10.01)
    }

    @Test(arguments: [false, true])
    func removingOwnersDestroysBothNewKinds(_ pogo: Bool) async throws {
        let fixture = try await PhysicsJoint2DFixture()
        let a = fixture.body(mode: .static)
        let b = fixture.body(at: [0, 2])
        let descriptor = try pogo ? PhysicsJoint2DDescriptor.pogo(entityA: a, entityB: b) : PhysicsJoint2DDescriptor.mover(entityA: a, entityB: b)
        let joint = try await fixture.connect(descriptor)
        let id = try fixture.native(joint)
        fixture.app.main.removeEntity(joint)
        await fixture.app.main.runScheduler(.physicsSync)
        #expect(!b2Joint_IsValid(id))
    }

    @Test
    func invalidNormalsAndForceCapsAreRejected() async throws {
        let fixture = try await PhysicsJoint2DFixture()
        let a = fixture.body(mode: .static)
        let b = fixture.body()
        #expect(throws: PhysicsJoint2DError.invalidSettings) {
            try PhysicsJoint2DDescriptor.pogo(entityA: a, entityB: b, settings: .init(normal: .zero))
        }
        #expect(throws: PhysicsJoint2DError.invalidSettings) {
            try PhysicsJoint2DDescriptor.mover(entityA: a, entityB: b, settings: .init(maximumVelocityForce: [-1, 0]))
        }
    }
}
