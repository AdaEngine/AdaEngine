//
//  PhysicsWorld2D.swift
//  AdaEngine
//
//  Created by v.prusakov on 7/6/22.
//

import AdaECS
import AdaUtils
import box2d
import Math

/// A protocol that defines a delegate for the physics world.
public protocol PhysicsWorld2DDelegate: AnyObject, Sendable {
    /// Called when the physics world is about to solve a collision.
    ///
    /// - Parameters:
    ///   - world: The physics world.
    ///   - entityA: The first entity.
    ///   - entityB: The second entity.
    ///   - manifold: The manifold.
    /// - Returns: A Boolean value indicating whether the collision should be solved.
    func physicsWorldOnPreSolve(
        _ world: PhysicsWorld2D,
        entityA: Entity,
        entityB: Entity,
        manifold: Manifold2D?
    ) -> Bool

    /// Called when the physics world is about to filter a collision.
    ///
    /// - Parameters:
    ///   - world: The physics world.
    ///   - entityA: The first entity.
    ///   - entityB: The second entity.
    /// - Returns: A Boolean value indicating whether the collision should be filtered.
    func physicsWorldOnCustomFilterCalled(
        _ world: PhysicsWorld2D,
        entityA: Entity,
        entityB: Entity
    ) -> Bool
}

/// An object that holds and simulates all 2D physics bodies.
public final class PhysicsWorld2D: Codable, @unchecked Sendable {
    /// The coding keys for the physics world.
    enum CodingKeys: CodingKey {
        case substepIterations
        case gravity
        case coordinateOrigin
    }

    /// The delegate of the physics world.
    public weak var delegate: PhysicsWorld2DDelegate? {
        didSet {
            // A delegate may change its collision decisions without moving either body.
            b2World_SetContactRecycleDistance(worldId, delegate == nil ? defaultContactRecycleDistance : 0)
        }
    }

    /// The substep iterations.
    public var substepIterations: Int = 4

    /// Contains world gravity.
    public var gravity: Vector2 {
        get {
            b2World_GetGravity(worldId).asVector2
        }
        set {
            b2World_SetGravity(worldId, newValue.b2Vec)
        }
    }

    /// Enable/disable continuous collision between dynamic and static bodies.
    /// Generally you should keep continuous collision enabled to prevent fast moving objects from
    /// going through static objects. The performance gain from disabling continuous collision is minor.
    public var isContinuousEnabled: Bool {
        get {
            b2World_IsContinuousEnabled(worldId)
        }
        set {
            b2World_EnableContinuous(worldId, newValue)
        }
    }

    /// Enable/disable constraint warm starting. Advanced feature for testing.
    /// Disabling sleeping greatly reduces stability and provides no performance gain.
    public var isWarmStartingEnabled: Bool {
        get {
            b2World_IsWarmStartingEnabled(worldId)
        }
        set {
            b2World_EnableWarmStarting(worldId, newValue)
        }
    }

    /// Enable/disable sleep. If your application does not need sleeping, you can gain
    /// some performance by disabling sleep completely at the world level.
    public var isSleepEnabled: Bool {
        get {
            b2World_IsSleepingEnabled(worldId)
        }
        set {
            b2World_EnableSleeping(worldId, newValue)
        }
    }

    /// Adjust the restitution threshold. It is recommended not to make this value very small
    /// because it will prevent bodies from sleeping. Usually in meters per second.
    public var restitutionThreshold: Float {
        get {
            b2World_GetRestitutionThreshold(worldId)
        }
        set {
            b2World_SetRestitutionThreshold(worldId, newValue)
        }
    }

    /// Adjust the hit event threshold. This controls the collision speed needed to generate a b2ContactHitEvent.
    /// Usually in meters per second.
    public var hitEventThreshold: Float {
        get {
            b2World_GetHitEventThreshold(worldId)
        }
        set {
            b2World_SetHitEventThreshold(worldId, newValue)
        }
    }
    // Native constraints belong to this world. Records never retain bodies or their world.
    @MainActor var jointRecords: [Entity.ID: RuntimeJoint2D] = [:]
    @MainActor var seenJointOwners: Set<Entity.ID> = []
    @MainActor var retiredJointOwners: [Entity.ID] = []
    @MainActor var jointThresholdIDs: Set<UInt64> = []
    @MainActor var jointThresholdNotices: [JointThresholdNotice2D] = []
    @MainActor var characterRecords: [Entity.ID: CharacterRuntime2D] = [:]
    @MainActor var seenCharacters: Set<Entity.ID> = []
    @MainActor var retiredCharacters: [Entity.ID] = []
    /// Global origin of the nearby frame used by Float APIs and render transforms.
    public internal(set) var coordinateOrigin: PhysicsPosition2D = .zero
    let worldId: b2WorldId
    private let defaultContactRecycleDistance: Float
    var eventManager: EventManager = .default
    weak var eventSource: World?
    // A world-local bus avoids a global subscription retaining its owning ECS world.
    let ecsEventManager = EventManager()

    /// - Parameter gravity: default gravity is 9.8.
    nonisolated init(
        gravity: Vector2 = [0, -9.81],
        workerCount: Int = PhysicsSimulationThreading.recommendedWorkerCount
    ) {
        var worldDef = unsafe b2DefaultWorldDef()
        unsafe worldDef.gravity = gravity.b2Vec
        unsafe worldDef.enableSleep = true
        unsafe worldDef.enableContinuous = true
        #if WASM
            unsafe worldDef.workerCount = 1
        #else
            // Box2D 3.2 owns its worker threads when task callbacks are not supplied.
            unsafe worldDef.workerCount = Int32(max(1, min(Int(B2_MAX_WORKERS), workerCount)))
        #endif
        self.worldId = unsafe b2CreateWorldDoublePrecision(&worldDef)
        b2World_EnableWarmStarting(worldId, true)
        self.defaultContactRecycleDistance = b2World_GetContactRecycleDistance(worldId)

        let unsafeWorldPtr = unsafe Unmanaged.passUnretained(self).toOpaque()
        unsafe b2World_SetPreSolveCallback(
            worldId, PhysicsWorld2D_PreSolve, PhysicsWorld2D_PreContinuous, unsafeWorldPtr
        )
        unsafe b2World_SetCustomFilterCallback(worldId, PhysicsWorld2D_CustomFilterCallback, unsafeWorldPtr)
    }

    deinit {
        b2DestroyWorld(worldId)
    }

    nonisolated public convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let gravity = try container.decode(Vector2.self, forKey: .gravity)

        self.init(gravity: gravity)

        self.substepIterations = try container.decode(Int.self, forKey: .substepIterations)
        let origin = try container.decodeIfPresent(PhysicsPosition2D.self, forKey: .coordinateOrigin) ?? .zero
        guard origin.isFinite else { throw DecodingError.dataCorruptedError(forKey: .coordinateOrigin, in: container, debugDescription: "Invalid coordinate origin") }
        self.coordinateOrigin = origin
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.gravity, forKey: .gravity)
        try container.encode(coordinateOrigin, forKey: .coordinateOrigin)
        try container.encode(self.substepIterations, forKey: .substepIterations)
    }

    // MARK: - Raycasting

    /// Casts a finite segment. Results are sorted by distance; `.first` returns the nearest hit.
    /// Initially overlapping shapes are ignored, following Box2D ray-cast semantics.
    /// Invalid or zero-length segments return no hits. Call between simulation steps.
    public func raycast(
        from startPoint: Vector2,
        to endPoint: Vector2,
        query: CollisionCastQueryType = .all,
        mask: CollisionGroup = .all
    ) -> [Raycast2DHit] {
        let translation = endPoint - startPoint
        let length = translation.squaredLength.squareRoot()
        guard startPoint.x.isFinite, startPoint.y.isFinite,
            endPoint.x.isFinite, endPoint.y.isFinite, length.isFinite, length > 0,
            !mask.isEmpty
        else {
            return []
        }
        var filter = b2DefaultQueryFilter()
        filter.categoryBits = UInt64.max
        filter.maskBits = mask.rawValue
        var collector = Raycast2DCollector(length: length, query: query, origin: coordinateOrigin)
        // Box2D invokes the callback synchronously; the stack context never escapes this call.
        unsafe withUnsafeMutablePointer(to: &collector) { context in
            _ = unsafe b2World_CastRay(
                worldId, nativePosition(startPoint), translation.b2Vec, filter, PhysicsWorld2D_Raycast, context
            )
        }
        return collector.results.sorted { $0.distance < $1.distance }
    }

    /// Casts along a ray's XY direction, normalized, up to `maxDistance` world units.
    /// The default range is 10,000 units. Invalid ranges or directions return no hits.
    public func raycast(
        from ray: Ray,
        maxDistance: Float = 10_000,
        query: CollisionCastQueryType = .all,
        mask: CollisionGroup = .all
    ) -> [Raycast2DHit] {
        let direction = ray.direction.xy
        let length = direction.squaredLength.squareRoot()
        guard length.isFinite, length > 0, maxDistance.isFinite, maxDistance > 0 else {
            return []
        }
        return raycast(
            from: ray.origin.xy,
            to: ray.origin.xy + (direction / length) * maxDistance,
            query: query,
            mask: mask
        )
    }

    // MARK: - Internal

    @MainActor
    func updateSimulation(_ delta: TimeInterval) {
        b2World_Step(
            worldId,
            Float(delta), /* timeStep */
            Int32(self.substepIterations) /* velocityIterations */
        )
    }

    func recordPerformance(into metrics: PhysicsPerformanceMetrics) {
        metrics.record(
            b2World_GetProfile(worldId),
            counters: b2World_GetCounters(worldId)
        )
    }

    /// Iterates the contiguous Box2D move-event stream produced by the latest simulation step.
    func forEachMovedBody(_ body: (Entity, Vector2, Quat) -> Void) {
        let events = unsafe b2World_GetBodyEvents(worldId)
        guard unsafe events.moveCount > 0, let moveEvents = unsafe events.moveEvents else {
            return
        }

        for index in unsafe 0..<Int(events.moveCount) {
            let event = unsafe moveEvents[index]
            // A collision subscriber may have destroyed this body after the step.
            // The copied move-event userData is then dangling, even though the event remains buffered.
            guard b2Body_IsValid(event.bodyId), let userData = unsafe event.userData else {
                continue
            }

            let runtimeBody = unsafe Unmanaged<Body2D>.fromOpaque(userData).takeUnretainedValue()
            guard let entity = runtimeBody.entity else {
                continue
            }

            let globalPosition = unsafe PhysicsPosition2D(event.transform.p)
            if var coordinate = entity.components[PhysicsPosition2DComponent.self] {
                coordinate.position = globalPosition
                entity.components[PhysicsPosition2DComponent.self] = coordinate
            }
            let position = globalPosition.displacement(from: coordinateOrigin)
            let rotation = unsafe Quat(
                axis: [0, 0, 1],
                angle: b2Rot_GetAngle(event.transform.q)
            )

            body(
                entity,
                position,
                rotation
            )
        }
    }

    func debugDraw(with definitions: b2DebugDraw) {
        var definitions = unsafe definitions
        unsafe b2World_Draw(worldId, &definitions)
    }

    @MainActor
    func processContacts() {
        let contactEvents = unsafe b2World_GetContactEvents(self.worldId)

        // Subscribers may destroy bodies or shapes. Snapshot the native buffers before delivery.
        let begins = unsafe Array(UnsafeBufferPointer(start: contactEvents.beginEvents, count: Int(contactEvents.beginCount)))
        let ends = unsafe Array(UnsafeBufferPointer(start: contactEvents.endEvents, count: Int(contactEvents.endCount)))
        let hits = unsafe Array(UnsafeBufferPointer(start: contactEvents.hitEvents, count: Int(contactEvents.hitCount)))
        for event in begins { onBeginContact(event) }
        for event in ends { onEndContact(event) }
        for event in hits { onHitContact(event) }
    }

    @MainActor
    func processSensors() {
        let sensorEvents = unsafe b2World_GetSensorEvents(self.worldId)
        let begins = unsafe Array(UnsafeBufferPointer(start: sensorEvents.beginEvents, count: Int(sensorEvents.beginCount)))
        let ends = unsafe Array(UnsafeBufferPointer(start: sensorEvents.endEvents, count: Int(sensorEvents.endCount)))
        for event in begins { onSensorBeginContact(event) }
        for event in ends { onSensorEndContact(event) }
    }

    nonisolated func destroyBody(_ body: Body2D) {
        if b2Body_IsValid(body.bodyId) { b2DestroyBody(body.bodyId) }
    }

    func createBody(with definition: b2BodyDef, for entity: Entity) -> Body2D {
        let body = unsafe withUnsafePointer(to: definition) {
            unsafe b2CreateBody(self.worldId, $0)
        }

        let body2d = Body2D(world: self, bodyId: body, entity: entity)
        let pointer = unsafe Unmanaged.passUnretained(body2d).toOpaque()
        unsafe b2Body_SetUserData(body, pointer)

        return body2d
    }
}

extension PhysicsWorld2D {
    @MainActor
    private func onSensorBeginContact(_ contact: b2SensorBeginTouchEvent) {
        let shapeIdA = BoxShape2D(shape: contact.sensorShapeId)
        let shapeIdB = BoxShape2D(shape: contact.visitorShapeId)
        guard shapeIdA.isValid, shapeIdB.isValid else {
            return
        }
        let bodyA = shapeIdA.body
        let bodyB = shapeIdB.body

        guard let entityA = bodyA?.entity, let entityB = bodyB?.entity else {
            return
        }

        let event = CollisionEvents.Began(
            entityA: entityA,
            entityB: entityB,
            impulse: 0,
            isSensor: true
        )

        send(event)
    }

    @MainActor
    private func onSensorEndContact(_ contact: b2SensorEndTouchEvent) {
        let shapeIdA = BoxShape2D(shape: contact.sensorShapeId)
        let shapeIdB = BoxShape2D(shape: contact.visitorShapeId)

        guard shapeIdA.isValid && shapeIdB.isValid else {
            return
        }

        guard shapeIdA.isValid, shapeIdB.isValid else {
            return
        }
        let bodyA = shapeIdA.body
        let bodyB = shapeIdB.body

        guard let entityA = bodyA?.entity, let entityB = bodyB?.entity else {
            return
        }

        let event = CollisionEvents.Ended(
            entityA: entityA,
            entityB: entityB,
            isSensor: true
        )

        send(event)
    }

    @MainActor
    private func onBeginContact(_ contact: b2ContactBeginTouchEvent) {
        let shapeIdA = BoxShape2D(shape: contact.shapeIdA)
        let shapeIdB = BoxShape2D(shape: contact.shapeIdB)
        guard shapeIdA.isValid, shapeIdB.isValid else {
            return
        }
        let bodyA = shapeIdA.body
        let bodyB = shapeIdB.body

        guard let entityA = bodyA?.entity, let entityB = bodyB?.entity else {
            return
        }

        let event = CollisionEvents.Began(
            entityA: entityA,
            entityB: entityB,
            impulse: contactImpulse(contact.contactId)
        )

        send(event)
    }

    @MainActor
    private func onEndContact(_ contact: b2ContactEndTouchEvent) {
        let shapeIdA = BoxShape2D(shape: contact.shapeIdA)
        let shapeIdB = BoxShape2D(shape: contact.shapeIdB)

        guard shapeIdA.isValid && shapeIdB.isValid else {
            return
        }

        guard shapeIdA.isValid, shapeIdB.isValid else {
            return
        }
        let bodyA = shapeIdA.body
        let bodyB = shapeIdB.body

        guard let entityA = bodyA?.entity, let entityB = bodyB?.entity else {
            return
        }

        let event = CollisionEvents.Ended(
            entityA: entityA,
            entityB: entityB
        )

        send(event)
    }

    @MainActor
    private func onHitContact(_ contact: b2ContactHitEvent) {
        let shapeA = BoxShape2D(shape: contact.shapeIdA)
        let shapeB = BoxShape2D(shape: contact.shapeIdB)
        guard shapeA.isValid, shapeB.isValid,
            let entityA = shapeA.body?.entity, let entityB = shapeB.body?.entity else {
            return
        }
        send(CollisionEvents.Hit(
            entityA: entityA,
            entityB: entityB,
            point: localPosition(contact.point),
            globalPoint: PhysicsPosition2D(contact.point),
            normal: contact.normal.asVector2,
            approachSpeed: contact.approachSpeed,
            impulse: contactImpulse(contact.contactId)
        ))
    }

    private func contactImpulse(_ contact: b2ContactId) -> Float {
        guard b2Contact_IsValid(contact) else {
            return 0
        }
        let manifold = b2Contact_GetData(contact).manifold
        let first = manifold.pointCount > 0 ? manifold.points.0.totalNormalImpulse : 0
        let second = manifold.pointCount > 1 ? manifold.points.1.totalNormalImpulse : 0
        return first + second
    }

    func send<T: Event>(_ event: T) {
        ecsEventManager.send(event)
        if let eventSource {
            eventManager.send(event, source: eventSource)
        } else {
            eventManager.send(event)
        }
    }
}

private func PhysicsWorld2D_PreSolve(
    _ shapeA: b2ShapeId,
    _ shapeB: b2ShapeId,
    _ manifold: UnsafeMutablePointer<b2Manifold>?,
    _ context: UnsafeMutableRawPointer?
) {
    let contact = unsafe manifold.map { ptr in
        unsafe Manifold2D(
            normal: ptr.pointee.normal.asVector2,
            rollingImpulse: ptr.pointee.rollingImpulse
        )
    }
    if unsafe !PhysicsWorld2D_ShouldSolve(shapeA, shapeB, manifold: contact, context: context) {
        unsafe manifold?.pointee.pointCount = 0
    }
}

private func PhysicsWorld2D_PreContinuous(
    _ shapeA: b2ShapeId,
    _ shapeB: b2ShapeId,
    _: b2Pos,
    _: b2Vec2,
    _ context: UnsafeMutableRawPointer?
) -> Bool {
    // Continuous collision has no manifold yet, as in the previous Box2D callback.
    unsafe PhysicsWorld2D_ShouldSolve(shapeA, shapeB, manifold: nil, context: context)
}

private func PhysicsWorld2D_ShouldSolve(
    _ shapeA: b2ShapeId,
    _ shapeB: b2ShapeId,
    manifold: Manifold2D?,
    context: UnsafeMutableRawPointer?
) -> Bool {
    guard let context = unsafe context else {
        return false
    }
    let world = unsafe Unmanaged<PhysicsWorld2D>.fromOpaque(context).takeUnretainedValue()
    let shapeIdA = BoxShape2D(shape: shapeA)
    let shapeIdB = BoxShape2D(shape: shapeB)

    guard shapeIdA.isValid && shapeIdB.isValid else {
        return false
    }
    guard let entityA = shapeIdA.body?.entity, let entityB = shapeIdB.body?.entity else {
        return false
    }
    return world.delegate?.physicsWorldOnPreSolve(
        world, entityA: entityA, entityB: entityB, manifold: manifold
    ) ?? true
}

private func PhysicsWorld2D_CustomFilterCallback(
    _ shapeA: b2ShapeId,
    _ shapeB: b2ShapeId,
    _ context: UnsafeMutableRawPointer?
) -> Bool {
    guard let context = unsafe context else {
        return true
    }
    let world = unsafe Unmanaged<PhysicsWorld2D>.fromOpaque(context).takeUnretainedValue()
    let shapeIdA = BoxShape2D(shape: shapeA)
    let shapeIdB = BoxShape2D(shape: shapeB)

    guard shapeIdA.isValid && shapeIdB.isValid else {
        return true
    }

    let bodyA = shapeIdA.body
    let bodyB = shapeIdB.body

    guard let entityA = bodyA?.entity, let entityB = bodyB?.entity else {
        return true
    }

    return world.delegate?
        .physicsWorldOnCustomFilterCalled(
            world,
            entityA: entityA,
            entityB: entityB
        ) ?? true
}

// MARK: - Casting

extension Vector2 {
    /// World position conversion; local geometry and velocities use b2Vec.
    var b2Position: b2Pos { b2ToPos(b2Vec) }

    var b2Vec: b2Vec2 {
        get {
            return unsafe unsafeBitCast(self, to: b2Vec2.self)
        }

        set {
            self = unsafe unsafeBitCast(newValue, to: Vector2.self)
        }
    }
}

extension b2Pos {
    var asVector2: Vector2 { Vector2(Float(x), Float(y)) }
}

extension b2Vec2 {
    var asVector2: Vector2 {
        return unsafe unsafeBitCast(self, to: Vector2.self)
    }
}

extension PhysicsBodyMode {
    var b2Type: b2BodyType {
        switch self {
        case .static: return b2_staticBody
        case .dynamic: return b2_dynamicBody
        case .kinematic: return b2_kinematicBody
        }
    }

    init(b2BodyType: b2BodyType) {
        switch b2BodyType {
        case b2_staticBody: self = .static
        case b2_dynamicBody: self = .dynamic
        case b2_kinematicBody: self = .kinematic
        default:
            self = .static
        }
    }
}

/// A manifold of a collision.
public struct Manifold2D: Sendable {
    /// The normal of the manifold.
    public let normal: Vector2
    /// The rolling impulse of the manifold.
    public let rollingImpulse: Float
}
