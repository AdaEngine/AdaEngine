import AdaECS
@testable import AdaPhysics
import AdaUtils
import box2d
import Foundation
import Math
import Synchronization
import Testing

@MainActor
@Suite(.serialized)
struct Physics2DJointBreakingTests {
    private func step(_ fixture: PhysicsJoint2DFixture, count: Int = 1) throws {
        let physics = try #require(fixture.app.main.physicsWorld2D)
        for _ in 0..<count { physics.updateSimulation(1.0 / 60); physics.processJointEvents() }
    }

    @Test
    func forceThresholdBreaksOnceAndRequiresExplicitReconnect() async throws {
        let fixture = try await PhysicsJoint2DFixture(gravity: [0, -10])
        fixture.app.main.insertResource(FixedTime(deltaTime: 1.0 / 60))
        await fixture.app.main.runScheduler(.startup)
        let a = fixture.body(mode: .static)
        let b = fixture.body(at: [0, -2])
        let descriptor = try PhysicsJoint2DDescriptor.distance(entityA: a, entityB: b, settings: .init(length: 2)).withBreakSettings(.init(forceThreshold: 100))
        let decoded = try JSONDecoder().decode(PhysicsJoint2DDescriptor.self, from: JSONEncoder().encode(descriptor))
        let joint = try await fixture.connect(decoded)
        let log = JointThresholdLog()
        let subscription = fixture.app.main.subscribe(to: Joint2DEvents.ThresholdExceeded.self) { log.append($0) }
        defer { subscription.cancel() }
        try step(fixture, count: 10)
        #expect(log.events.isEmpty)
        try joint.components[PhysicsJoint2DComponent.self]?.updateBreakSettings(.init(forceThreshold: 1))
        await fixture.app.main.runScheduler(.physicsStep)
        #expect(log.events.count == 1 && log.events.first?.didBreak == true)
        #expect(log.events.first?.jointOwner === joint)
        #expect(joint.components[PhysicsJoint2DComponent.self]?.isBroken == true)
        #expect(joint.components[PhysicsJoint2DComponent.self]?.isConnected == false)
        let ecs = Events<Joint2DEvents.ThresholdExceeded>()
        ecs.update(from: fixture.app.main)
        #expect(ecs.currentEvents.count == 1)
        for _ in 0..<5 { await fixture.app.main.runScheduler(.physicsSync); try step(fixture) }
        #expect(log.events.count == 1)
        b.components.remove(PhysicsBody2DComponent.self)
        await fixture.app.main.runScheduler(.physicsSync)
        b.components[PhysicsBody2DComponent.self] = PhysicsBody2DComponent(shapes: [.generateBox()], mass: 1)
        await fixture.app.main.runScheduler(.physicsSync)
        #expect(joint.components[PhysicsJoint2DComponent.self]?.isBroken == true)
        joint.components[PhysicsJoint2DComponent.self]?.reconnect()
        await fixture.app.main.runScheduler(.physicsSync)
        #expect(joint.components[PhysicsJoint2DComponent.self]?.isConnected == true)
        #expect(joint.components[PhysicsJoint2DComponent.self]?.isBroken == false)
    }

    @Test
    func notificationOnlyTorqueThresholdRearmsAfterQuietSteps() async throws {
        let fixture = try await PhysicsJoint2DFixture()
        let a = fixture.body(mode: .static)
        let b = fixture.body()
        let descriptor = try PhysicsJoint2DDescriptor.weld(entityA: a, entityB: b).withBreakSettings(.init(torqueThreshold: 1, removeOnBreak: false))
        let joint = try await fixture.connect(descriptor)
        let log = JointThresholdLog()
        let subscription = fixture.app.main.subscribe(to: Joint2DEvents.ThresholdExceeded.self) { log.append($0) }
        defer { subscription.cancel() }
        b.components[PhysicsBody2DComponent.self]?.applyTorque(100, wake: true)
        try step(fixture)
        #expect(log.events.count == 1 && log.events.first?.didBreak == false)
        #expect(joint.components[PhysicsJoint2DComponent.self]?.isConnected == true)
        try step(fixture, count: 60)
        b.components[PhysicsBody2DComponent.self]?.applyTorque(100, wake: true)
        try step(fixture)
        #expect(log.events.count == 2)
        #expect(log.events.allSatisfy { $0.torque.isFinite && $0.force.x.isFinite && !$0.didBreak })
    }

    @Test
    func subscriberRemovalUsesSnapshotsAndOtherWorldsReceiveNothing() async throws {
        let fixture = try await PhysicsJoint2DFixture(gravity: [0, -10])
        let other = try await PhysicsJoint2DFixture()
        let a = fixture.body(mode: .static)
        let b = fixture.body(at: [-2, -2])
        let c = fixture.body(at: [2, -2])
        let settings = JointBreak2DSettings(forceThreshold: 0.1, removeOnBreak: false)
        _ = try await fixture.connect(PhysicsJoint2DDescriptor.rope(entityA: a, entityB: b).withBreakSettings(settings))
        _ = try await fixture.connect(PhysicsJoint2DDescriptor.rope(entityA: a, entityB: c).withBreakSettings(settings))
        let log = JointThresholdLog()
        let foreign = JointThresholdLog()
        let world = fixture.app.main
        let first = world.subscribe(to: Joint2DEvents.ThresholdExceeded.self) { event in
            log.append(event)
            world.removeEntity(b)
            world.removeEntity(c)
        }
        let second = other.app.main.subscribe(to: Joint2DEvents.ThresholdExceeded.self) { foreign.append($0) }
        defer { first.cancel(); second.cancel() }
        try step(fixture)
        #expect(log.events.count == 2)
        #expect(foreign.events.isEmpty)
        await world.runScheduler(.physicsSync)
        #expect(b2World_GetCounters(try #require(world.physicsWorld2D).worldId).jointCount == 0)
    }

    @Test
    func invalidThresholdsAreRejectedAndProxyDoesNotRetainWorld() async throws {
        weak var physics: PhysicsWorld2D?
        do {
            let fixture = try await PhysicsJoint2DFixture()
            await fixture.app.main.runScheduler(.startup)
            let a = fixture.body(mode: .static)
            let b = fixture.body(at: [2, 0])
            let descriptor = PhysicsJoint2DDescriptor.rope(entityA: a, entityB: b)
            #expect(throws: PhysicsJoint2DError.invalidSettings) { try descriptor.withBreakSettings(.init(forceThreshold: -1)) }
            let configured = try descriptor.withBreakSettings(.init(forceThreshold: 100))
            let joint = try await fixture.connect(configured)
            try joint.components[PhysicsJoint2DComponent.self]?.updateSettings(DistanceJoint2DSettings(length: 1))
            #expect(joint.components[PhysicsJoint2DComponent.self]?.jointDescriptor.breakSettings == .init(forceThreshold: 100))
            var legacy = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(configured)) as? [String: Any])
            legacy.removeValue(forKey: "breakSettings")
            let legacyData = try JSONSerialization.data(withJSONObject: legacy)
            #expect(try JSONDecoder().decode(PhysicsJoint2DDescriptor.self, from: legacyData).breakSettings == .init())
            physics = fixture.app.main.physicsWorld2D
        }
        #expect(physics == nil)
    }
}

private final class JointThresholdLog: Sendable {
    private let storage = Mutex<[Joint2DEvents.ThresholdExceeded]>([])
    func append(_ event: Joint2DEvents.ThresholdExceeded) { storage.withLock { $0.append(event) } }
    var events: [Joint2DEvents.ThresholdExceeded] { storage.withLock { $0 } }
}
