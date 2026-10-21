import AdaECS
@testable import AdaPhysics
import AdaTransform
import AdaUtils
import Math
import Synchronization
import Testing

@MainActor
private final class ContactEventLog2D {
    var began: [CollisionEvents.Began] = []
    var hits: [CollisionEvents.Hit] = []
    var sensors: [CollisionEvents.Began] = []
    var ended: [CollisionEvents.Ended] = []
}

private final class ContactDelegate2D: PhysicsWorld2DDelegate {
    let manifolds = Mutex<[Manifold2D]>([])
    func physicsWorldOnPreSolve(_ world: PhysicsWorld2D, entityA: Entity, entityB: Entity, manifold: Manifold2D?) -> Bool {
        if let manifold { manifolds.withLock { $0.append(manifold) } }
        return true
    }
    func physicsWorldOnCustomFilterCalled(_ world: PhysicsWorld2D, entityA: Entity, entityB: Entity) -> Bool { true }
}

@MainActor
@Suite(.serialized)
struct Physics2DContactEventTests {
    @Test func snapshotsSurviveSubscriberRemovalAcrossContactHitAndSensorStreams() async throws {
        let fixture = try await PhysicsJoint2DFixture()
        let physics = try #require(fixture.app.main.physicsWorld2D)
        fixture.app.main.spawn { Collision2DComponent(shapes: [.generateBox(width: 20, height: 1)]); Transform(position: [0, -0.5, 0]) }
        let a = fixture.body(at: [-3, 0.49])
        let b = fixture.body(at: [3, 0.49])
        fixture.app.main.spawn { Collision2DComponent(shapes: [.generateBox(width: 2, height: 3)], mode: .trigger); Transform(position: [3, 0.5, 0]) }
        a.components[PhysicsBody2DComponent.self]?.linearVelocity = [0, -5]
        b.components[PhysicsBody2DComponent.self]?.linearVelocity = [0, -5]
        let log = ContactEventLog2D()
        let began = fixture.app.main.subscribe(to: CollisionEvents.Began.self) { event in
            MainActor.assumeIsolated {
                if event.isSensor { log.sensors.append(event) } else {
                    log.began.append(event)
                    b.components.remove(PhysicsBody2DComponent.self)
                }
            }
        }
        let hits = fixture.app.main.subscribe(to: CollisionEvents.Hit.self) { event in MainActor.assumeIsolated { log.hits.append(event) } }
        defer { began.cancel(); hits.cancel() }
        await fixture.app.main.runScheduler(.physicsSync)
        physics.updateSimulation(1.0 / 60)
        physics.processContacts()
        physics.processSensors()
        #expect(log.began.count == 2)
        let hit = try #require(log.hits.first { $0.entityA === b || $0.entityB === b })
        let snapshot = try #require(hit.contact)
        #expect(hit.contactID == snapshot.id && hit.impulse > 0)
        #expect(snapshot.manifold.points.contains { $0.totalNormalImpulse > 0 })
        #expect(!physics.isValid(snapshot.id))
        #expect(log.sensors.contains { $0.entityB === b && $0.contactID == nil && $0.contact == nil })
        physics.processContacts(); physics.processSensors()
        #expect(log.began.count == 2)
    }

    @Test func endedCarriesAnExplicitlyExpiredHandle() async throws {
        let fixture = try await PhysicsJoint2DFixture()
        let a = fixture.body(at: [-0.2, 0])
        let b = fixture.body(at: [0.2, 0], mode: .static)
        let log = ContactEventLog2D()
        let began = fixture.app.main.subscribe(to: CollisionEvents.Began.self) { event in MainActor.assumeIsolated { log.began.append(event) } }
        let ended = fixture.app.main.subscribe(to: CollisionEvents.Ended.self) { event in MainActor.assumeIsolated { log.ended.append(event) } }
        defer { began.cancel(); ended.cancel() }
        await fixture.app.main.runScheduler(.physicsSync)
        let physics = try #require(fixture.app.main.physicsWorld2D)
        physics.updateSimulation(1.0 / 60); physics.processContacts()
        let id = try #require(log.began.first?.contactID)
        a.components[PhysicsBody2DComponent.self]?.setPosition([-10, 0])
        physics.updateSimulation(1.0 / 60); physics.processContacts()
        #expect(log.ended.contains { $0.contactID == id })
        #expect(!physics.isValid(id))
        #expect(b.components[PhysicsBody2DComponent.self] != nil)
    }

    @Test func preSolveProvidesFullPointsWithPhaseAndUnavailableVelocity() async throws {
        let fixture = try await PhysicsJoint2DFixture()
        let physics = try #require(fixture.app.main.physicsWorld2D)
        let origin = PhysicsPosition2D(x: 1e9, y: -1e9)
        #expect(physics.setCoordinateOrigin(origin))
        fixture.app.main.spawn {
            Collision2DComponent(shapes: [.generateBox(width: 10, height: 1)])
            Transform()
            PhysicsPosition2DComponent(origin.offset(by: [0, -0.5]))
        }
        let box = fixture.body()
        box.components[PhysicsPosition2DComponent.self] = .init(origin.offset(by: [0, 0.49]))
        let delegate = ContactDelegate2D()
        physics.delegate = delegate
        await fixture.app.main.runScheduler(.physicsSync)
        physics.updateSimulation(1.0 / 60)
        let manifold = try #require(delegate.manifolds.withLock { $0.first })
        #expect(manifold.phase == .preSolve && manifold.points.count == 2)
        #expect(manifold.points.allSatisfy { $0.normalVelocity == nil && abs($0.globalPoint.y - origin.y) < 0.1 })
    }
}
