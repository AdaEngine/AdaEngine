import AdaECS
@testable import AdaPhysics
import AdaTransform
import AdaUtils
import box2d
import Foundation
import Math
import Testing

@MainActor
@Suite(.serialized)
struct Physics2DOriginMechanismTests {
    private func step(_ fixture: PhysicsJoint2DFixture, _ count: Int) async {
        for _ in 0..<count {
            await fixture.app.main.runScheduler(.physicsSync)
            await fixture.app.main.runScheduler(.physicsStep)
            await fixture.app.main.runScheduler(.physicsWriteback)
        }
    }

    @Test(arguments: [CharacterController2DMode.query, .dynamic])
    func charactersGroundMoveAndJumpAcrossOriginChanges(_ mode: CharacterController2DMode) async throws {
        let fixture = try await PhysicsJoint2DFixture(gravity: [0, -10])
        fixture.app.main.insertResource(FixedTime(deltaTime: 1.0 / 60))
        let physics = try #require(fixture.app.main.physicsWorld2D)
        let origin = PhysicsPosition2D(x: 1e9 + 0.125, y: -1e9 + 0.25)
        #expect(physics.setCoordinateOrigin(origin))
        fixture.app.main.spawn {
            Transform()
            Collision2DComponent(shapes: [.generateBox(width: 100, height: 1)])
            PhysicsPosition2DComponent(origin.offset(by: [0, -0.5]))
        }
        var controller = CharacterController2DComponent()
        controller.mode = mode
        let entity = fixture.app.main.spawn { controller; Transform(); PhysicsPosition2DComponent(origin.offset(by: [0, 2])) }
        await step(fixture, 120)
        #expect(entity.components[CharacterController2DComponent.self]?.isGrounded == true)
        let before = try #require(entity.components[PhysicsPosition2DComponent.self]?.position)
        let record = entity.components[CharacterController2DComponent.self]?.runtime
        let nativeID = record?.body.map { b2StoreBodyId($0.bodyId) }
        #expect(physics.setCoordinateOrigin(origin.offset(by: [100, -50])))
        await step(fixture, 1)
        #expect(entity.components[CharacterController2DComponent.self]?.isGrounded == true)
        let rebased = try #require(entity.components[PhysicsPosition2DComponent.self]?.position)
        #expect(abs(rebased.x - before.x) < 0.001 && abs(rebased.y - before.y) < 0.02)
        if let nativeID { #expect(entity.components[CharacterController2DComponent.self]?.runtime?.body.map { b2StoreBodyId($0.bodyId) } == nativeID) }
        entity.components[CharacterController2DComponent.self]?.desiredVelocity = [2, 0]
        await step(fixture, 60)
        #expect(try #require(entity.components[PhysicsPosition2DComponent.self]?.position).x > origin.x + 1)
        entity.components[CharacterController2DComponent.self]?.jumpRequested = true
        await step(fixture, 20)
        #expect(try #require(entity.components[PhysicsPosition2DComponent.self]?.position).y > origin.y + 0.5)
        #expect(entity.components[CharacterController2DComponent.self]?.lastError == nil)
        let shapes = physics.collectDebugShapes(options: [.showPhysicsShapes, .showJoints])
        #expect(shapes.lines.allSatisfy { abs($0.start.x) < 500 && abs($0.start.y) < 500 && abs($0.end.x) < 500 && abs($0.end.y) < 500 })
    }

    @Test func exactWorldHingeKeepsPivotAndIdentityWhileRetuning() async throws {
        let fixture = try await PhysicsJoint2DFixture(gravity: [0, -10])
        let physics = try #require(fixture.app.main.physicsWorld2D)
        let origin = PhysicsPosition2D(x: 1e9 + 0.125, y: 1e9 + 0.25)
        #expect(physics.setCoordinateOrigin(origin))
        let bob = fixture.body()
        bob.components[PhysicsPosition2DComponent.self] = .init(origin.offset(by: [0, -1]))
        let descriptor = try PhysicsJoint2DDescriptor.revolute(entity: bob, globalAnchor: origin)
        let decoded = try JSONDecoder().decode(PhysicsJoint2DDescriptor.self, from: JSONEncoder().encode(descriptor))
        let owner = try await fixture.connect(decoded)
        let joint = try fixture.native(owner)
        let id = b2StoreJointId(joint)
        try fixture.step(60)
        #expect(physics.setCoordinateOrigin(origin.offset(by: [100, 100])))
        // Publish the completed native step before syncing authoritative authored positions again.
        await fixture.app.main.runScheduler(.physicsWriteback)
        await fixture.app.main.runScheduler(.physicsSync)
        try owner.components[PhysicsJoint2DComponent.self]?.updateSettings(RevoluteJoint2DSettings())
        try fixture.step(60)
        let pivot = b2Body_GetWorldPoint(b2Joint_GetBodyB(joint), b2Joint_GetLocalFrameB(joint).p)
        #expect(abs(pivot.x - origin.x) < 0.02 && abs(pivot.y - origin.y) < 0.02)
        #expect(b2StoreJointId(try fixture.native(owner)) == id)
        let debug = physics.collectDebugShapes(options: [.showPhysicsShapes, .showJoints])
        #expect(!debug.lines.isEmpty)
        #expect(debug.lines.allSatisfy { abs($0.start.x) < 200 && abs($0.start.y) < 200 })
    }
}
