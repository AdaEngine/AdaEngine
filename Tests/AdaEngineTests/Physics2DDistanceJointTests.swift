@_spi(Internal) @testable import AdaApp
import AdaECS
@testable import AdaPhysics
import AdaTransform
import box2d
import Foundation
import Math
import Testing

@MainActor
@Suite(.serialized)
struct Physics2DDistanceJointTests {
    private func makeWorld() async throws -> AppWorlds {
        let app = AppWorlds(main: World())
        app.addPlugin(MainSchedulerPlugin()).addPlugin(TransformPlugin()).addPlugin(Physics2DPlugin(gravity: .zero))
        try await app.build()
        return app
    }
    private func body(_ app: AppWorlds, x: Float, mode: PhysicsBodyMode = .dynamic) -> Entity {
        app.main.spawn { PhysicsBody2DComponent(shapes: [.generateCircle(radius: 0.2)], mass: 1, mode: mode); Transform(position: [x, 0, 0]) }
    }
    private func advance(_ app: AppWorlds, steps: Int = 120) throws {
        let physics = try #require(app.main.physicsWorld2D)
        for _ in 0..<steps { physics.updateSimulation(1.0 / 60) }
    }
    private func length(_ entity: Entity) throws -> Float {
        let joint = try #require(entity.components[PhysicsJoint2DComponent.self]?.runtimeJoint)
        return b2DistanceJoint_GetCurrentLength(joint.id)
    }

    @Test
    func rigidAndSpringConstraintsUseNativeAnchors() async throws {
        let app = try await makeWorld()
        let anchor = body(app, x: 0, mode: .static)
        let bob = body(app, x: 4)
        let settings = DistanceJoint2DSettings(length: 2, frameA: .init(position: [1, 0]), spring: .init(hertz: 4))
        let descriptor = try PhysicsJoint2DDescriptor.distance(entityA: anchor, entityB: bob, settings: settings)
        let joint = app.main.spawn { PhysicsJoint2DComponent(joint: descriptor) }
        await app.main.runScheduler(.physicsSync)
        #expect(joint.components[PhysicsJoint2DComponent.self]?.isConnected == true)
        try advance(app)
        #expect(abs(try length(joint) - 2) < 0.02)
        joint.components[PhysicsJoint2DComponent.self]?.jointDescriptor = try .distance(entityA: anchor, entityB: bob, settings: .init(length: 1))
        await app.main.runScheduler(.physicsSync)
        try advance(app)
        #expect(abs(try length(joint) - 1) < 0.02)
    }

    @Test
    func legacyRopeAllowsSlackAndStopsExtension() async throws {
        let app = try await makeWorld()
        let a = body(app, x: 0, mode: .static)
        let b = body(app, x: 4)
        let encoded = try JSONEncoder().encode(PhysicsJoint2DComponent(joint: .rope(entityA: a, entityB: b)))
        let component = try JSONDecoder().decode(PhysicsJoint2DComponent.self, from: encoded)
        let joint = app.main.spawn { component }
        await app.main.runScheduler(.physicsSync)
        b.components[PhysicsBody2DComponent.self]?.linearVelocity = [10, 0]
        try advance(app)
        #expect(try length(joint) < 4.03)
        b.components[PhysicsBody2DComponent.self]?.setPosition([1, 0])
        b.components[PhysicsBody2DComponent.self]?.linearVelocity = .zero
        try advance(app, steps: 10)
        #expect(try length(joint) < 1.02)
    }

    @Test
    func motorDrivesDistanceInsideLimits() async throws {
        let app = try await makeWorld()
        let a = body(app, x: 0, mode: .static)
        let b = body(app, x: 2)
        let descriptor = try PhysicsJoint2DDescriptor.distance(
            entityA: a,
            entityB: b,
            settings: .init(length: 2, limits: .init(lower: 1, upper: 3), motor: .init(speed: 2, maximumEffort: 100))
        )
        let joint = app.main.spawn { PhysicsJoint2DComponent(joint: descriptor) }
        await app.main.runScheduler(.physicsSync)
        try advance(app)
        #expect(try length(joint) > 2.9 && length(joint) < 3.03)
        let native = try #require(joint.components[PhysicsJoint2DComponent.self]?.runtimeJoint)
        #expect(abs(b2DistanceJoint_GetCurrentMotorForce(native.id)) <= 100.01)
    }

    @Test
    func lateBodiesRemovalAndRecreationDoNotLeakNativeConstraints() async throws {
        let app = try await makeWorld()
        let a = body(app, x: 0, mode: .static)
        let b = app.main.spawn { Transform(position: [2, 0, 0]) }
        let descriptor = try PhysicsJoint2DDescriptor.distance(entityA: a, entityB: b, settings: .init(length: 2))
        let joint = app.main.spawn { PhysicsJoint2DComponent(joint: descriptor) }
        await app.main.runScheduler(.physicsSync)
        #expect(joint.components[PhysicsJoint2DComponent.self]?.jointError == .missingBody)
        b.components[PhysicsBody2DComponent.self] = PhysicsBody2DComponent(shapes: [.generateCircle(radius: 0.2)], mass: 1)
        await app.main.runScheduler(.physicsSync)
        let old = try #require(joint.components[PhysicsJoint2DComponent.self]?.runtimeJoint)
        b.components.remove(PhysicsBody2DComponent.self)
        #expect(!old.isConnected)
        await app.main.runScheduler(.physicsSync)
        #expect(app.main.physicsWorld2D?.jointRecords.isEmpty == true)
        b.components[PhysicsBody2DComponent.self] = PhysicsBody2DComponent(shapes: [.generateCircle(radius: 0.2)], mass: 1)
        await app.main.runScheduler(.physicsSync)
        #expect(joint.components[PhysicsJoint2DComponent.self]?.isConnected == true)
        joint.components.remove(PhysicsJoint2DComponent.self)
        await app.main.runScheduler(.physicsSync)
        #expect(b2World_GetCounters(try #require(app.main.physicsWorld2D).worldId).jointCount == 0)
        joint.components[PhysicsJoint2DComponent.self] = PhysicsJoint2DComponent(joint: descriptor)
        await app.main.runScheduler(.physicsSync)
        app.main.removeEntity(joint)
        await app.main.runScheduler(.physicsSync)
        #expect(b2World_GetCounters(try #require(app.main.physicsWorld2D).worldId).jointCount == 0)
    }

    @Test
    func invalidSettingsAndCrossWorldPairsAreRejectedAndSettingsRoundTrip() async throws {
        let app = try await makeWorld()
        let other = try await makeWorld()
        let a = body(app, x: 0)
        let b = body(app, x: 2)
        #expect(throws: PhysicsJoint2DError.invalidBodyPair) { try PhysicsJoint2DDescriptor.distance(entityA: a, entityB: a, settings: .init(length: 1)) }
        let foreign = body(other, x: 2)
        #expect(throws: PhysicsJoint2DError.invalidBodyPair) { try PhysicsJoint2DDescriptor.distance(entityA: a, entityB: foreign, settings: .init(length: 1)) }
        #expect(throws: PhysicsJoint2DError.invalidSettings) { try PhysicsJoint2DDescriptor.distance(entityA: a, entityB: b, settings: .init(length: -1)) }
        let invalid = PhysicsJoint2DDescriptor(joint: .distance(a.id, b.id, .init(length: -1)))
        let badData = try JSONEncoder().encode(invalid)
        #expect(throws: PhysicsJoint2DError.invalidSettings) { try JSONDecoder().decode(PhysicsJoint2DDescriptor.self, from: badData) }
        let descriptor = try PhysicsJoint2DDescriptor.distance(entityA: a, entityB: b, settings: .init(length: 1, spring: .init(hertz: 3)))
        let decoded = try JSONDecoder().decode(PhysicsJoint2DDescriptor.self, from: JSONEncoder().encode(descriptor))
        let joint = app.main.spawn { PhysicsJoint2DComponent(joint: decoded) }
        await app.main.runScheduler(.physicsSync)
        try advance(app)
        #expect(abs(try length(joint) - 1) < 0.02)
    }

    @Test
    func recordsDoNotRetainDisposedWorlds() async throws {
        var retained: RuntimeJoint2D?
        weak var physics: PhysicsWorld2D?
        do {
            let app = try await makeWorld()
            let a = body(app, x: 0, mode: .static)
            let b = body(app, x: 2)
            let joint = app.main.spawn { PhysicsJoint2DComponent(joint: .rope(entityA: a, entityB: b)) }
            await app.main.runScheduler(.physicsSync)
            physics = app.main.physicsWorld2D
            retained = joint.components[PhysicsJoint2DComponent.self]?.runtimeJoint
        }
        #expect(physics == nil)
        #expect(retained?.isConnected == false)
    }
}
