@_spi(Internal) @testable import AdaApp
import AdaECS
@testable import AdaPhysics
import AdaTransform
import AdaUtils
import Math
import Synchronization
import Testing

@MainActor
@Suite(.serialized)
struct Physics2DQueryEventTests {
    private func makeWorld() async throws -> AppWorlds {
        let app = AppWorlds(main: World())
        app.addPlugin(MainSchedulerPlugin()).addPlugin(Physics2DPlugin(gravity: .zero)).addPlugin(TransformPlugin())
        try await app.build()
        app.main.insertResource(FixedTime(deltaTime: 1.0 / 60))
        await app.main.runScheduler(.startup)
        return app
    }

    private func wall(in world: World, at x: Float, group: CollisionGroup = .default) -> Entity {
        world.spawn {
            Collision2DComponent(shapes: [.generateBox(width: 1, height: 4)], filter: CollisionFilter(categoryBitMask: group))
            Transform(position: [x, 0, 0])
        }
    }

    private func step(_ app: AppWorlds, count: Int = 1) async {
        for _ in 0..<count {
            await app.main.runScheduler(.physicsSync)
            await app.main.runScheduler(.physicsStep)
            await app.main.runScheduler(.physicsWriteback)
        }
    }

    @Test
    func raycastReturnsAllSortedAndNearestWithWorldDistances() async throws {
        let app = try await makeWorld()
        let far = wall(in: app.main, at: 7)
        let near = wall(in: app.main, at: 3)
        await app.main.runScheduler(.physicsSync)
        let physics = try #require(app.main.physicsWorld2D)
        let all = physics.raycast(from: [0, 0], to: [10, 0])
        #expect(all.map(\.entity.id) == [near.id, far.id])
        let first = try #require(all.first)
        #expect(abs(first.distance - 2.5) < 0.001)
        #expect(abs(first.point.x - 2.5) < 0.001)
        #expect(first.normal.x < -0.99)
        #expect(abs(try #require(all.last).distance - 6.5) < 0.001)
        let closest = physics.raycast(from: [0, 0], to: [10, 0], query: .first)
        #expect(closest.count == 1)
        #expect(closest.first?.entity.id == near.id)
        #expect(closest.first?.distance == first.distance)
        let reverse = physics.raycast(from: [10, 0], to: [0, 0])
        #expect(reverse.map(\.entity.id) == [far.id, near.id])
        #expect(abs(try #require(reverse.first).distance - 2.5) < 0.001)
    }

    @Test(arguments: [CollisionCastQueryType.first, .all])
    func raycastHandlesMissesEmptyWorldInvalidInputAndMasks(_ query: CollisionCastQueryType) async throws {
        let app = try await makeWorld()
        let physics = try #require(app.main.physicsWorld2D)
        #expect(physics.raycast(from: [0, 0], to: [10, 0], query: query).isEmpty)
        let selected = wall(in: app.main, at: 5, group: CollisionGroup(rawValue: 2))
        _ = wall(in: app.main, at: 2)
        await app.main.runScheduler(.physicsSync)
        #expect(physics.raycast(from: [0, 0], to: [10, 0], query: query, mask: CollisionGroup(rawValue: 2)).map(\.entity.id) == [selected.id])
        #expect(physics.raycast(from: [0, 8], to: [10, 8], query: query).isEmpty)
        #expect(physics.raycast(from: [0, 0], to: [0, 0], query: query).isEmpty)
        #expect(physics.raycast(from: [.nan, 0], to: [10, 0], query: query).isEmpty)
        #expect(physics.raycast(from: [0, 0], to: [.infinity, 0], query: query).isEmpty)
        #expect(physics.raycast(from: [0, 0], to: [10, 0], query: query, mask: []).isEmpty)
        // Box2D ignores shapes containing the ray origin.
        #expect(physics.raycast(from: [5, 0], to: [6, 0], query: query).isEmpty)
    }

    @Test
    func rayUsesOriginDirectionAndExplicitRange() async throws {
        let app = try await makeWorld()
        let target = wall(in: app.main, at: 13)
        await app.main.runScheduler(.physicsSync)
        let physics = try #require(app.main.physicsWorld2D)
        let ray = Ray(origin: [10, 0, 0], direction: [7, 0, 0])
        let hit = try #require(physics.raycast(from: ray, maxDistance: 5).first)
        #expect(hit.entity.id == target.id)
        #expect(abs(hit.distance - 2.5) < 0.001)
        #expect(physics.raycast(from: ray, maxDistance: 2).isEmpty)
        #expect(physics.raycast(from: ray, maxDistance: -1).isEmpty)
        #expect(physics.raycast(from: ray, maxDistance: .infinity).isEmpty)
        #expect(physics.raycast(from: Ray(origin: .zero, direction: .zero)).isEmpty)
    }

    @Test(arguments: [false, true])
    func sensorsEmitBeginAndEndWithoutPhysicalResponse(_ dynamicSensor: Bool) async throws {
        let app = try await makeWorld()
        let log = EventLog()
        let began = app.main.subscribe(to: CollisionEvents.Began.self) { log.began($0) }
        let ended = app.main.subscribe(to: CollisionEvents.Ended.self) { log.ended($0) }
        let hit = app.main.subscribe(to: CollisionEvents.Hit.self) { log.hit($0) }
        defer { began.cancel(); ended.cancel(); hit.cancel() }
        let sensor = app.main.spawn {
            if dynamicSensor {
                PhysicsBody2DComponent(shapes: [.generateBox(width: 2, height: 4)], mass: 1, isTrigger: true)
            } else {
                Collision2DComponent(shapes: [.generateBox(width: 2, height: 4)], mode: .trigger)
            }
            Transform()
        }
        var moving = PhysicsBody2DComponent(shapes: [.generateBox(width: 1, height: 1)], mass: 1)
        moving.linearVelocity = [4, 0]
        let visitor = app.main.spawn { moving; Transform(position: [-3, 0, 0]) }
        await step(app, count: 120)
        let snapshot = log.snapshot
        #expect(snapshot.begins.count == 1)
        #expect(snapshot.ends.count == 1)
        let begin = try #require(snapshot.begins.first)
        #expect(begin.isSensor && begin.entityA === sensor && begin.entityB === visitor)
        #expect(begin.impulse == 0)
        #expect(snapshot.ends.first?.isSensor == true)
        #expect(snapshot.ends.first?.entityA === sensor)
        #expect(snapshot.hits.isEmpty)
        #expect(try #require(visitor.components[Transform.self]).position.x > 4.9)
        let ecsBegins = Events<CollisionEvents.Began>()
        ecsBegins.update(from: app.main)
        #expect(ecsBegins.currentEvents.count == 1)
        await app.main.runScheduler(.preUpdate)
        #expect(ecsBegins.count == 1)
        #expect(ecsBegins.currentEvents.isEmpty)
        await app.main.runScheduler(.preUpdate)
        #expect(ecsBegins.isEmpty)
    }

    @Test
    func solidCollisionEmitsImpactAndEndAndReachesECS() async throws {
        let app = try await makeWorld()
        let log = EventLog()
        let began = app.main.subscribe(to: CollisionEvents.Began.self) { log.began($0) }
        let ended = app.main.subscribe(to: CollisionEvents.Ended.self) { log.ended($0) }
        let hit = app.main.subscribe(to: CollisionEvents.Hit.self) { log.hit($0) }
        defer { began.cancel(); ended.cancel(); hit.cancel() }
        let wall = wall(in: app.main, at: 0)
        var moving = PhysicsBody2DComponent(shapes: [.generateBox(width: 1, height: 1)], mass: 1)
        moving.linearVelocity = [8, 0]
        let visitor = app.main.spawn { moving; Transform(position: [-3, 0, 0]) }
        await step(app, count: 30)
        let snapshot = log.snapshot
        #expect(snapshot.begins.count == 1)
        #expect(snapshot.begins.first?.isSensor == false)
        #expect(try #require(snapshot.begins.first).impulse > 0)
        let impact = try #require(snapshot.hits.first)
        #expect(Set([impact.entityA.id, impact.entityB.id]) == Set([wall.id, visitor.id]))
        #expect(impact.approachSpeed > 7)
        #expect(impact.impulse > 0)
        #expect(abs(impact.normal.x) > 0.99)
        #expect(impact.point.x.isFinite && impact.point.y.isFinite)
        let ecsHits = Events<CollisionEvents.Hit>()
        ecsHits.update(from: app.main)
        #expect(!ecsHits.currentEvents.isEmpty)
        visitor.components[PhysicsBody2DComponent.self]?.setPosition([-5, 0])
        await step(app)
        #expect(log.snapshot.ends.count == 1)
        #expect(log.snapshot.ends.first?.isSensor == false)
    }

    @Test(arguments: [false, true])
    func masksSuppressContactsAndSensorsAndWorldsDoNotShareEvents(_ sensor: Bool) async throws {
        let first = try await makeWorld()
        let other = try await makeWorld()
        let log = EventLog()
        let subscription = other.main.subscribe(to: CollisionEvents.Began.self) { log.began($0) }
        defer { subscription.cancel() }
        _ = wall(in: first.main, at: 0)
        first.main.spawn {
            PhysicsBody2DComponent(shapes: [.generateBox(width: 1, height: 1)], mass: 1)
            Transform(position: [-0.75, 0, 0])
        }
        await step(first)
        #expect(log.snapshot.begins.isEmpty)
        let otherEvents = Events<CollisionEvents.Began>()
        otherEvents.update(from: other.main)
        #expect(otherEvents.currentEvents.isEmpty)
        let firstEvents = Events<CollisionEvents.Began>()
        firstEvents.update(from: first.main)
        #expect(firstEvents.currentEvents.count == 1)

        let filtered = try await makeWorld()
        filtered.main.spawn {
            Collision2DComponent(shapes: [.generateBox(width: 3, height: 3)], mode: sensor ? .trigger : .default, filter: CollisionFilter(collisionBitMask: []))
            Transform()
        }
        filtered.main.spawn {
            PhysicsBody2DComponent(shapes: [.generateBox(width: 1, height: 1)], mass: 1)
            Transform()
        }
        await step(filtered, count: 3)
        let filteredEvents = Events<CollisionEvents.Began>()
        filteredEvents.update(from: filtered.main)
        #expect(filteredEvents.currentEvents.isEmpty)
    }

    @Test
    func fastVisitorSweepsThroughSensorAndExitsOnFollowingStep() async throws {
        let app = try await makeWorld()
        app.main.insertResource(FixedTime(deltaTime: 1.0 / 30))
        app.main.spawn {
            Collision2DComponent(shapes: [.generateBox(width: 1, height: 4)], mode: .trigger)
            Transform()
        }
        var moving = PhysicsBody2DComponent(shapes: [.generateBox(width: 0.5, height: 0.5)], mass: 1)
        moving.linearVelocity = [300, 0]
        let visitor = app.main.spawn { moving; Transform(position: [-5, 0, 0]) }
        await step(app)
        #expect(try #require(visitor.components[Transform.self]).position.x > 4)
        let begins = Events<CollisionEvents.Began>()
        let ends = Events<CollisionEvents.Ended>()
        begins.update(from: app.main)
        ends.update(from: app.main)
        #expect(begins.currentEvents.count == 1)
        #expect(ends.currentEvents.isEmpty)
        #expect(begins.currentEvents.first?.isSensor == true)
        // Box2D keeps swept overlaps until the next step, when it reports the exit.
        await step(app)
        #expect(ends.currentEvents.count == 1)
    }

    @Test
    func subscribersCanRemoveBodiesDuringEventDelivery() async throws {
        let app = try await makeWorld()
        _ = wall(in: app.main, at: 0)
        for y: Float in [-0.5, 0.5] {
            app.main.spawn {
                PhysicsBody2DComponent(shapes: [.generateBox(width: 1, height: 1)], mass: 1)
                Transform(position: [-0.75, y, 0])
            }
        }
        let subscription = app.main.subscribe(to: CollisionEvents.Began.self) { event in
            MainActor.assumeIsolated {
                event.entityA.components[PhysicsBody2DComponent.self] = nil
                event.entityB.components[PhysicsBody2DComponent.self] = nil
            }
        }
        defer { subscription.cancel() }
        await step(app, count: 3)
        #expect(app.main.getEntities().allSatisfy { $0.components[PhysicsBody2DComponent.self] == nil })
    }

    @Test
    func eventProxyDoesNotRetainItsWorld() async throws {
        var app: AppWorlds? = try await makeWorld()
        weak var world = app?.main
        app = nil
        #expect(world == nil)
    }

    @Test
    func removedBodiesDoNotCrashPendingEndEvents() async throws {
        let app = try await makeWorld()
        _ = wall(in: app.main, at: 0)
        let body = app.main.spawn {
            PhysicsBody2DComponent(shapes: [.generateBox(width: 1, height: 1)], mass: 1)
            Transform(position: [-0.75, 0, 0])
        }
        await step(app)
        body.components[PhysicsBody2DComponent.self] = nil
        await step(app, count: 2)
        #expect(body.components[PhysicsBody2DComponent.self] == nil)
    }
}

private final class EventLog: Sendable {
    struct Snapshot: Sendable {
        var begins: [CollisionEvents.Began] = []
        var ends: [CollisionEvents.Ended] = []
        var hits: [CollisionEvents.Hit] = []
    }
    private let state = Mutex(Snapshot())
    var snapshot: Snapshot { state.withLock { $0 } }
    func began(_ event: CollisionEvents.Began) { state.withLock { $0.begins.append(event) } }
    func ended(_ event: CollisionEvents.Ended) { state.withLock { $0.ends.append(event) } }
    func hit(_ event: CollisionEvents.Hit) { state.withLock { $0.hits.append(event) } }
}
