//
//  PhysicsWorld2D.swift
//
//
//  Created by v.prusakov on 7/6/22.
//

@_implementationOnly import AdaBox2d
import Math

public final class PhysicsWorld2D: Codable {
    
    enum CodingKeys: CodingKey {
        case velocityIterations
        case positionIterations
        case gravity
    }
    
    private var world: OpaquePointer!
    
    weak var scene: Scene?
    
    public var velocityIterations: Int = 6
    public var positionIterations: Int = 2
    
    public var gravity: Vector2 {
        get {
            return b2_world_get_gravity(self.world).asVector2
        }

        set {
            b2_world_set_gravity(self.world, newValue.b2Vec)
        }
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
    
    let contactListner = _Physics2DContactListener()
    
    /// - Parameter gravity: default gravity is 9.8.
    init(gravity: Vector2 = [0, -9.81]) {
        self.world = b2_world_create(gravity.b2Vec)
        b2_world_set_contact_listener(self.world, self.contactListner.contactListener)
    }
    
    deinit {
        b2_world_destroy(self.world)
    }
    
    internal func updateSimulation(_ delta: Float) {
        b2_world_step(
            self.world,
            delta, /* timeStep */
            Int32(self.velocityIterations), /* velocityIterations */
            Int32(self.positionIterations) /* positionIterations */
        )
    }
    
    public func createBody(definition: Body2DDefinition, for entity: Entity) -> Body2D {
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
        let pointer = Unmanaged.passRetained(body2d).toOpaque()
        b2_body_set_user_data(ref, pointer)
        
        return body2d
    }
//    
//    public func createJoint(_ jointPtr: UnsafePointer<b2JointDef>) -> OpaquePointer {
//        self.world.CreateJoint(jointPtr)
//    }
//    
//    public func destroyJoint(_ joint: OpaquePointer) {
//        self.world.DestroyJoint(joint)
//    }
//    
    public func destroyBody(_ body: Body2D) {
        b2_world_destroy_body(self.world, body.ref)
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

// MARK: - b2ContactListener

// swiftlint:disable:next type_name
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

        let event = CollisionEvents.Began(
            entityA: bodyA.entity,
            entityB: bodyB.entity,
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
        
        let event = CollisionEvents.Ended(
            entityA: bodyA.entity,
            entityB: bodyB.entity
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
