import AdaECS
@testable import AdaPhysics
import box2d
import Foundation
import Math
import Testing

@MainActor
@Suite(.serialized)
struct Physics2DBodyMotionTests {
    @Test func axisLocksHandleForcesAndLiveUnlockPreservesAuthoredMass() async throws {
        let fixture = try await PhysicsJoint2DFixture()
        let entity = fixture.body()
        var motion = PhysicsBody2DMotion()
        motion.lockTranslationX = true; motion.lockTranslationY = true; motion.lockRotation = true
        try entity.components[PhysicsBody2DComponent.self]?.configureMotion(motion)
        await fixture.app.main.runScheduler(.physicsSync)
        let body = try #require(entity.components[PhysicsBody2DComponent.self]?.runtimeBody)
        let id = b2StoreBodyId(body.bodyId)
        body.applyForceToCenter([100, 100], wake: true)
        body.applyTorque(100, wake: true)
        try fixture.step(60)
        #expect(body.getPosition() == .zero && body.getAngularVelocity() == 0)
        motion.lockTranslationX = false; motion.lockRotation = false
        try entity.components[PhysicsBody2DComponent.self]?.configureMotion(motion)
        #expect(body.massData.mass == 1 && body.massData.rotationalInertia == 1)
        body.applyLinearImpulse([2, 2], point: .zero, wake: true)
        body.applyTorque(10, wake: true)
        try fixture.step(60)
        #expect(body.getPosition().x > 1 && body.getPosition().y == 0)
        #expect(body.getAngularVelocity() > 0)
        #expect(b2StoreBodyId(body.bodyId) == id)
        entity.components[PhysicsBody2DComponent.self]?.fixedRotation = true
        await fixture.app.main.runScheduler(.physicsSync)
        #expect(b2Body_GetMotionLocks(body.bodyId).angularZ)
        entity.components[PhysicsBody2DComponent.self]?.fixedRotation = false
        await fixture.app.main.runScheduler(.physicsSync)
        #expect(!b2Body_GetMotionLocks(body.bodyId).angularZ && body.massData.rotationalInertia == 1)
    }

    @Test func sleepingIsNotOverriddenBySyncAndCanBeControlledExplicitly() async throws {
        let fixture = try await PhysicsJoint2DFixture()
        let entity = fixture.body()
        var motion = PhysicsBody2DMotion()
        motion.initiallyAwake = false; motion.sleepThreshold = 0.1
        try entity.components[PhysicsBody2DComponent.self]?.configureMotion(motion)
        await fixture.app.main.runScheduler(.physicsSync)
        #expect(entity.components[PhysicsBody2DComponent.self]?.isAwake == false)
        entity.components[PhysicsBody2DComponent.self]?.setAwake(true)
        #expect(entity.components[PhysicsBody2DComponent.self]?.isAwake == true)
        try fixture.step(120)
        #expect(entity.components[PhysicsBody2DComponent.self]?.isAwake == false)
        await fixture.app.main.runScheduler(.physicsSync)
        #expect(entity.components[PhysicsBody2DComponent.self]?.isAwake == false)
        motion.isSleepEnabled = false
        try entity.components[PhysicsBody2DComponent.self]?.configureMotion(motion)
        try fixture.step(120)
        #expect(entity.components[PhysicsBody2DComponent.self]?.isAwake == true)
        let body = try #require(entity.components[PhysicsBody2DComponent.self]?.runtimeBody)
        #expect(!b2Body_IsSleepingEnabled(body.bodyId) && b2Body_GetSleepThreshold(body.bodyId) == 0.1)
    }

    @Test func motionSerializationDefaultsAndValidation() throws {
        var body = PhysicsBody2DComponent(shapes: [])
        var motion = PhysicsBody2DMotion()
        motion.lockTranslationY = true; motion.initiallyAwake = false
        try body.configureMotion(motion)
        let data = try JSONEncoder().encode(body)
        #expect(try JSONDecoder().decode(PhysicsBody2DComponent.self, from: data).motion == motion)
        var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "motion")
        #expect(try JSONDecoder().decode(PhysicsBody2DComponent.self, from: JSONSerialization.data(withJSONObject: object)).motion == PhysicsBody2DMotion())
        motion.sleepThreshold = -1
        #expect(throws: PhysicsBody2DSettingsError.invalidMotion) { try body.configureMotion(motion) }
        #expect(body.motion.lockTranslationY)
    }
}
