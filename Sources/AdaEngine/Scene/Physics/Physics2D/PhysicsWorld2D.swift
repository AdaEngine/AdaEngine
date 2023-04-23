//
//  PhysicsWorld2D.swift
//  AdaEngine
//
//  Created by v.prusakov on 7/6/22.
//

@_implementationOnly import AdaBox2d
import Math

/// An object that holds and simulate all 2D physics bodies.
public final class PhysicsWorld2D: Codable {
    
    enum CodingKeys: CodingKey {
        case velocityIterations
        case positionIterations
        case gravity
    }
    
    public var velocityIterations: Int = 6
    public var positionIterations: Int = 2
    
    /// Contains world gravity.
    public var gravity: Vector2 {
        get {
            return b2_world_get_gravity(self.world).asVector2
        }

        set {
            b2_world_set_gravity(self.world, newValue.b2Vec)
        }
    }
    
    private var world: OpaquePointer!
    
    weak var scene: Scene?
    let contactListner = _Physics2DContactListener()
    
    /// - Parameter gravity: default gravity is 9.8.
    init(gravity: Vector2 = [0, -9.81]) {
        self.world = b2_world_create(gravity.b2Vec)
        b2_world_set_contact_listener(self.world, self.contactListner.contactListener)
    }
    
    deinit {
        b2_world_destroy(self.world)
    }
    
    public convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let gravity = try container.decode(Vector2.self, forKey: .gravity)

        self.init(gravity: gravity)

        self.velocityIterations = try container.decode(Int.self, forKey: .velocityIterations)
        self.positionIterations = try container.decode(Int.self, forKey: .positionIterations)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.gravity, forKey: .gravity)
        try container.encode(self.velocityIterations, forKey: .velocityIterations)
        try container.encode(self.positionIterations, forKey: .positionIterations)
    }
    
    // MARK: - Public
    
    /// Clear all forces in physics world.
    public func clearForces() {
        b2_world_clear_forces(self.world)
    }
    
    // MARK: - Raycasting
    
    /// An array of collision cast hit results.
    /// Each hit indicates where the ray, starting at a given point and traveling in a given direction, hit a particular entity in the scene.
    public func raycast(
        from startPoint: Vector2,
        to endPoint: Vector2,
        query: CollisionCastQueryType = .all,
        mask: CollisionGroup = .all
    ) -> [Raycast2DHit] {
        var raycastCallback = _Raycast2DCallback(startPoint: startPoint, endPoint: endPoint, query: query, mask: mask)
        
        let callbacks = raycast_listener_callback { userData, fixture, point, normal, fraction in
            let raycast = Unmanaged<_Raycast2DCallback>.fromOpaque(userData!).takeUnretainedValue()
            return raycast.reportFixture(fixture!, point: point, normal: normal, fraction: fraction)
        }
        
        b2_world_raycast(self.world, startPoint.b2Vec, endPoint.b2Vec, &raycastCallback, callbacks)
        
        return raycastCallback.results
    }
    
    /// An array of collision cast hit results.
    /// Each hit indicates where the ray, starting at a given point and traveling in a given direction, hit a particular entity in the scene.
    public func raycast(
        from ray: Ray,
        query: CollisionCastQueryType = .all,
        mask: CollisionGroup = .all
    ) -> [Raycast2DHit] {
        return self.raycast(from: ray.origin.xy, to: ray.direction.xy, query: query, mask: mask)
    }
    
    // MARK: - Internal
    
    internal func updateSimulation(_ delta: Float) {
        b2_world_step(
            self.world,
            delta, /* timeStep */
            Int32(self.velocityIterations), /* velocityIterations */
            Int32(self.positionIterations) /* positionIterations */
        )
    }
    
    internal func destroyBody(_ body: Body2D) {
        b2_world_destroy_body(self.world, body.ref)
    }
    
    internal func createBody(definition: Body2DDefinition, for entity: Entity) -> Body2D {
        var bodyDef = b2_body_def()
        bodyDef.angle = definition.angle
        bodyDef.position = definition.position.b2Vec
        bodyDef.type = definition.bodyMode.b2Type
        bodyDef.gravityScale = definition.gravityScale
        bodyDef.allowSleep = definition.allowSleep
        bodyDef.fixedRotation = definition.fixedRotation
        bodyDef.bullet = definition.bullet
        bodyDef.awake = definition.awake
        
        bodyDef.angularDamping = definition.angularDamping
        bodyDef.angularVelocity = definition.angularVelocity
        bodyDef.linearDamping = definition.linearDamping
        bodyDef.linearVelocity = definition.linearVelocity.b2Vec
        
        let ref = b2_world_create_body(self.world, bodyDef)!
        
        let body2d = Body2D(world: self, ref: ref, entity: entity)
        let pointer = Unmanaged.passUnretained(body2d).toOpaque()
        b2_body_set_user_data(ref, pointer)
        
        return body2d
    }
}

// MARK: - Casting

extension Vector2 {
    var b2Vec: b2_vec2 {
        get {
            return unsafeBitCast(self, to: b2_vec2.self)
        }
        
        set {
            self = unsafeBitCast(newValue, to: Vector2.self)
        }
    }
}

extension b2_vec2 {
    var asVector2: Vector2 {
        return unsafeBitCast(self, to: Vector2.self)
    }
}

extension PhysicsBodyMode {
    var b2Type: b2_body_type {
        switch self {
        case .static: return B2_BODY_TYPE_STATIC
        case .dynamic: return B2_BODY_TYPE_DYNAMIC
        case .kinematic: return B2_BODY_TYPE_KINEMATIC
        }
    }

    init(b2BodyType: b2_body_type) {
        switch b2BodyType {
        case B2_BODY_TYPE_STATIC: self = .static
        case B2_BODY_TYPE_DYNAMIC: self = .dynamic
        case B2_BODY_TYPE_KINEMATIC: self = .kinematic
        default:
            self = .static
        }
    }
}

// MARK: - b2RaycastCallback

/// A hit result of a collision cast.
public struct Raycast2DHit {
    
    /// The entity that was hit.
    public let entity: Entity
    
    /// The point of the hit.
    public let point: Vector2
    
    /// The normal of the hit.
    public let normal: Vector2
    
    /// The distance from the ray origin to the hit, or the convex shape travel distance.
    public let distance: Float
}

fileprivate final class _Raycast2DCallback {
    
    var results: [Raycast2DHit] = []
    
    let startPoint: Vector2
    let endPoint: Vector2
    let query: CollisionCastQueryType
    let mask: CollisionGroup
    
    enum RaycastReporting {
        static let `continue`: Float = 1.0
        static let terminate: Float = 0.0
    }
    
    init(startPoint: Vector2, endPoint: Vector2, query: CollisionCastQueryType, mask: CollisionGroup) {
        self.startPoint = startPoint
        self.endPoint = endPoint
        self.query = query
        self.mask = mask
    }
    
    func reportFixture(_ fixture: OpaquePointer, point: b2_vec2, normal: b2_vec2, fraction: Float) -> Float {
        let fixtureBody = b2_fixture_get_body(fixture)!
        let userData = b2_body_get_user_data(fixtureBody)!
        
        let filterData = b2_fixture_get_filter_data(fixture)
        
        if !(filterData.maskBits == self.mask.rawValue) {
            return RaycastReporting.continue
        }
        
        let body = Unmanaged<Body2D>.fromOpaque(userData).takeUnretainedValue()
        
        defer {
            fixtureBody.deallocate()
        }
        
        guard let entity = body.entity else {
            return RaycastReporting.continue
        }
        
        // FIXME: Check distance
        let distance = (self.startPoint - self.endPoint).squaredLength * fraction
        
        let result = Raycast2DHit(
            entity: entity,
            point: point.asVector2,
            normal: normal.asVector2,
            distance: distance
        )
        
        self.results.append(result)
        
        if query == .first {
            return RaycastReporting.terminate
        } else {
            return RaycastReporting.continue
        }
    }
}

// MARK: - b2ContactListener

final class _Physics2DContactListener {

    lazy var contactListener: OpaquePointer = {
        let ptr = Unmanaged.passUnretained(self).toOpaque()
        let callbacks = contact_listener_callbacks { userData, contact in
            let listener = Unmanaged<_Physics2DContactListener>.fromOpaque(userData!).takeUnretainedValue()
            listener.beginContact(contact!)
        } end_contact: { userData, contact in
            let listener = Unmanaged<_Physics2DContactListener>.fromOpaque(userData!).takeUnretainedValue()
            listener.endContact(contact!)
        } pre_solve: { userData, contact, manifold in
            let listener = Unmanaged<_Physics2DContactListener>.fromOpaque(userData!).takeUnretainedValue()
            listener.preSolve(contact!, oldManifold: manifold!)
        } post_solve: { userData, contact, impulse in
            let listener = Unmanaged<_Physics2DContactListener>.fromOpaque(userData!).takeUnretainedValue()
            listener.postSolve(contact!, impulse: impulse!)
        }

        return b2_create_contactListener(ptr, callbacks)
    }()

    deinit {
        self.contactListener.deallocate()
    }

    func beginContact(_ contact: OpaquePointer) {
        let fixtureA = b2_contact_get_fixture_a(contact)!
        let fixtureB = b2_contact_get_fixture_b(contact)!
        
        let bodyFixtureA = b2_fixture_get_body(fixtureA)!
        let bodyFixtureB = b2_fixture_get_body(fixtureB)!
        
        let userDataA = b2_body_get_user_data(bodyFixtureA)!
        let userDataB = b2_body_get_user_data(bodyFixtureB)!
        
        // FIXME: We should get correct impulse of contact
        let manifold = b2_contact_get_manifold(contact)!
        
        defer {
            fixtureA.deallocate()
            fixtureB.deallocate()
            
            bodyFixtureA.deallocate()
            bodyFixtureB.deallocate()
            
            manifold.deallocate()
        }

        let bodyA = Unmanaged<Body2D>.fromOpaque(userDataA).takeUnretainedValue()
        let bodyB = Unmanaged<Body2D>.fromOpaque(userDataB).takeUnretainedValue()

//        let impulse = contact.GetManifold().pointee.points.0.normalImpulse

        guard let entityA = bodyA.entity, let entityB = bodyB.entity else {
            return
        }
        
        let event = CollisionEvents.Began(
            entityA: entityA,
            entityB: entityB,
            impulse: 0
        )

        bodyA.world.scene?.eventManager.send(event)
    }

    func endContact(_ contact: OpaquePointer) {
        let fixtureA = b2_contact_get_fixture_a(contact)!
        let fixtureB = b2_contact_get_fixture_b(contact)!
        
        let bodyFixtureA = b2_fixture_get_body(fixtureA)!
        let bodyFixtureB = b2_fixture_get_body(fixtureB)!
        
        let userDataA = b2_body_get_user_data(bodyFixtureA)!
        let userDataB = b2_body_get_user_data(bodyFixtureB)!
        
        defer {
            fixtureA.deallocate()
            fixtureB.deallocate()
            
            bodyFixtureA.deallocate()
            bodyFixtureB.deallocate()
        }

        let bodyA = Unmanaged<Body2D>.fromOpaque(userDataA).takeUnretainedValue()
        let bodyB = Unmanaged<Body2D>.fromOpaque(userDataB).takeUnretainedValue()
        
        guard let entityA = bodyA.entity, let entityB = bodyB.entity else {
            return
        }
        
        let event = CollisionEvents.Ended(
            entityA: entityA,
            entityB: entityB
        )

        bodyA.world.scene?.eventManager.send(event)
    }

    func postSolve(_ contact: OpaquePointer, impulse: OpaquePointer) {
        return
    }

    func preSolve(_ contact: OpaquePointer, oldManifold: OpaquePointer) {
        return
    }
}

extension OpaquePointer {
    
    // TODO: Should we deallocate it in this place?
    func deallocate() {
        UnsafeRawPointer(self).deallocate()
    }
}
