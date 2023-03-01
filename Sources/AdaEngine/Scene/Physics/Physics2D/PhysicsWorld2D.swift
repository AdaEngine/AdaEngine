//
//  PhysicsWorld2D.swift
//  
//
//  Created by v.prusakov on 7/6/22.
//

import box2d
import Math

public final class Body2D {
    unowned let world: PhysicsWorld2D
    unowned let entity: Entity
    
    @usableFromInline
    private(set) var ref: OpaquePointer
    
    internal init(world: PhysicsWorld2D, ref: OpaquePointer, entity: Entity) {
        self.world = world
        self.ref = ref
        self.entity = entity
    }
    
    @inlinable
    @inline(__always)
    func addFixture(for fixtureDef: UnsafePointer<b2FixtureDef>) {
        b2Body_CreateFixture(ref, fixtureDef)
    }
    
    @inlinable
    @inline(__always)
    func getPosition() -> Vector2 {
        return b2Body_GetPosition(self.ref).pointee.asVector2
    }
    
    @inlinable
    @inline(__always)
    func getAngle() -> Float {
        return b2Body_GetAngle(self.ref)
    }
    
    @inlinable
    @inline(__always)
    func getLinearVelocity() -> Vector2 {
        return b2Body_GetLinearVelocity(self.ref).pointee.asVector2
    }
    
    @inlinable
    @inline(__always)
    func getWorldCenter() -> Vector2 {
        return b2Body_GetWorldCenter(self.ref).pointee.asVector2
    }
    
    @inlinable
    @inline(__always)
    func getFixtureList() -> UnsafeMutablePointer<b2Fixture>? {
        return b2Body_GetFixtureList(self.ref)
    }
    
    @inlinable
    @inline(__always)
    func setTransform(position: Vector2, angle: Float) {
        b2Body_SetTransform(self.ref, position.b2Vec, angle)
    }
    
    /// Set the linear velocity of the center of mass.
    @inlinable
    @inline(__always)
    func setLinearVelocity(_ vector: Vector2) {
        b2Body_SetLinearVelocity(self.ref, vector.b2Vec)
    }
    
    /// Apply a force at a world point. If the force is not applied at the center of mass, it will generate a torque and affect the angular velocity. This wakes up the body.
    @inlinable
    @inline(__always)
    func applyForce(force: Vector2, point: Vector2, wake: Bool) {
        b2Body_ApplyForce(self.ref, force.b2Vec, point.b2Vec, wake)
    }
    
    /// Apply a force to the center of mass. This wakes up the body.
    @inlinable
    @inline(__always)
    func applyForceToCenter(_ force: Vector2, wake: Bool) {
        b2Body_ApplyForceToCenter(self.ref, force.b2Vec, wake)
    }
    
    /// Apply an impulse at a point. This immediately modifies the velocity.
    /// It also modifies the angular velocity if the point of application is not at the center of mass. This wakes up the body.
    @inlinable
    @inline(__always)
    func applyLinearImpulse(_ impulse: Vector2, point: Vector2, wake: Bool) {
        b2Body_ApplyLinearImpulse(self.ref, impulse.b2Vec, point.b2Vec, wake)
    }
    
    /// Apply a torque. This affects the angular velocity without affecting the linear velocity of the center of mass. This wakes up the body.
    @inlinable
    @inline(__always)
    func applyTorque(_ torque: Float, wake: Bool) {
        b2Body_ApplyTorque(self.ref, torque, wake)
    }
    
    /// Get the world linear velocity of a world point attached to this body.
    /// - Parameter worldPoint: point in world coordinates.
    /// - Returns: The world velocity of a point or zero if entity not attached to Physics2DWorld.
    @inlinable
    @inline(__always)
    func getLinearVelocityFromWorldPoint(_ worldPoint: Vector2) -> Vector2 {
        b2Body_GetLinearVelocityFromWorldPoint(self.ref, worldPoint.b2Vec).asVector2
    }
    
    /// Get the world velocity of a local point.
    /// - Parameter localPoint: point in local coordinates.
    /// - Returns: The world velocity of a point or zero if entity not attached to Physics2DWorld.
    @inlinable
    @inline(__always)
    func getLinearVelocityFromLocalPoint(_ localPoint: Vector2) -> Vector2 {
        b2Body_GetLinearVelocityFromLocalPoint(self.ref, localPoint.b2Vec).asVector2
    }
}

public struct Body2DDefinition {
    public var bodyMode: PhysicsBodyMode = .static
    public var position: Vector2 = .zero
    public var angle: Float = 0
    public var gravityScale: Float = 1
    public var linearVelocity: Vector2 = .zero
    
    public var angularVelocity: Float = 0
    public var linearDamping: Float = 0
    public var angularDamping: Float = 0
    public var allowSleep: Bool = true
    public var awake: Bool = true
    public var fixedRotation: Bool = false
    public var bullet: Bool = false
    public var isEnabled = true
}

public final class PhysicsWorld2D: Codable {
    
    enum CodingKeys: CodingKey {
        case velocityIterations
        case positionIterations
        case gravity
    }
    
    private var worldPtr: UnsafeMutablePointer<b2World>
    
    weak var scene: Scene?
    
    public var velocityIterations: Int = 6
    public var positionIterations: Int = 2
    
    public var gravity: Vector2 {
        get {
            return b2World_GetGravity(UnsafePointer(self.worldPtr)).asVector2
        }
        
        set {
            b2World_SetGravity(self.worldPtr, newValue.b2Vec)
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
    
    let contactListner = _Physics2DContactListner()
    
    /// - Parameter gravity: default gravity is 9.8.
    init(gravity: Vector2 = [0, -9.81]) {
        self.worldPtr = b2World_create(gravity.b2Vec)!
        
        b2World_SetContactListener(self.worldPtr, self.contactListner.contactListener)
    }
    
    deinit {
        worldPtr.deallocate()
    }
    
    internal func updateSimulation(_ delta: Float) {
        b2World_Step(
            self.worldPtr,
            delta, /* timeStep */
            int32(self.velocityIterations), /* velocityIterations */
            int32(self.positionIterations) /* positionIterations */
        )
    }
    
    public func createBody(definition: Body2DDefinition, for entity: Entity) -> Body2D {
        let body = b2BodyDef_create()!
        body.pointee.angle = definition.angle
        body.pointee.position = definition.position.b2Vec
        body.pointee.type = definition.bodyMode.b2Type
        body.pointee.gravityScale = definition.gravityScale
        body.pointee.allowSleep = definition.allowSleep
        body.pointee.fixedRotation = definition.fixedRotation
        body.pointee.bullet = definition.bullet
        body.pointee.awake = definition.awake
        
        body.pointee.angularDamping = definition.angularDamping
        body.pointee.angularVelocity = definition.angularVelocity
        body.pointee.linearDamping = definition.linearDamping
        body.pointee.linearVelocity = definition.linearVelocity.b2Vec
        
        let ref = b2World_CreateBody(self.worldPtr, body)!
        let body2d = Body2D(world: self, ref: ref, entity: entity)
        let pointer = Unmanaged.passRetained(body2d).toOpaque()
        
        let userData = b2Body_GetUserData(ref)
        userData.pointee.pointer = UInt(bitPattern: pointer)
        
        return body2d
    }
    
    public func createJoint(_ jointPtr: UnsafePointer<b2JointDef>) -> OpaquePointer {
        b2World_CreateJoint(self.worldPtr, jointPtr)
    }
    
    public func destroyJoint(_ joint: OpaquePointer) {
        b2World_DestroyJoint(self.worldPtr, joint)
    }
    
    public func destroyBody(_ body: Body2D) {
        b2World_DestroyBody(self.worldPtr, body.ref)
    }
    
}

// MARK: - Casting

extension Vector2 {
    @inlinable
    @inline(__always)
    var b2Vec: b2Vec2 {
        get {
            return unsafeBitCast(self, to: b2Vec2.self)
        }
        
        set {
            self = unsafeBitCast(newValue, to: Vector2.self)
        }
    }
}

extension b2Vec2 {
    @usableFromInline
    var asVector2: Vector2 {
        return unsafeBitCast(self, to: Vector2.self)
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

// MARK: - b2ContactListener

final class _Physics2DContactListner {
    
    typealias B2Contact = @convention(c) (UnsafeRawPointer?, OpaquePointer?) -> Void
    
    lazy var contactListener: UnsafeMutablePointer<b2ContactListener> = {
        let ptr = Unmanaged.passUnretained(self).toOpaque()
        let contactListner = ContactListener2D_create(UnsafeRawPointer(ptr))!
        contactListner.pointee.m_BeginContact = _beginContact(_:_:) as B2Contact
        contactListner.pointee.m_EndContact = _endContact(_:_:) as B2Contact
        return b2ContactListener_unsafeCast(contactListner)!
    }()
    
    deinit {
        self.contactListener.deallocate()
    }
    
    func beginContact(_ contact: OpaquePointer?) {
//        let bodyA = contact.fixtureA.body.userData as! Body2D
//        let bodyB = contact.fixtureB.body.userData as! Body2D
//
//        // FIXME: We should get correct impulse of contact
//        let impulse = contact.manifold.points.first?.normalImpulse
//
//        let event = CollisionEvents.Began(
//            entityA: bodyA.entity,
//            entityB: bodyB.entity,
//            impulse: impulse ?? 0
//        )
//
//        bodyA.world.scene?.eventManager.send(event)
    }
    
    func endContact(_ contact: OpaquePointer?) {
//        let bodyA = contact.fixtureA.body.userData as! Body2D
//        let bodyB = contact.fixtureB.body.userData as! Body2D
//
//        let event = CollisionEvents.Ended(
//            entityA: bodyA.entity,
//            entityB: bodyB.entity
//        )
//
//        bodyA.world.scene?.eventManager.send(event)
    }
    
    func postSolve(_ contact: OpaquePointer?, impulse: UnsafePointer<b2ContactImpulse>?) {
        return
    }
    
    func preSolve(_ contact: OpaquePointer?, oldManifold: UnsafePointer<b2Manifold>?) {
        return
    }
}

private func _beginContact(_ userData: UnsafeRawPointer?, _ contact: OpaquePointer?) {
    let listner = Unmanaged<_Physics2DContactListner>.fromOpaque(userData!).takeUnretainedValue()
    listner.beginContact(contact)
}

private func _endContact(_ userData: UnsafeRawPointer?, _ contact: OpaquePointer?) {
    let listner = Unmanaged<_Physics2DContactListner>.fromOpaque(userData!).takeUnretainedValue()
    listner.endContact(contact)
}

func _postSolve(_ userData: UnsafeRawPointer?, _ contact: OpaquePointer?, _ impulse: UnsafePointer<b2ContactImpulse>?) {
    let listner = Unmanaged<_Physics2DContactListner>.fromOpaque(userData!).takeUnretainedValue()
    listner.postSolve(contact, impulse: impulse)
}

func _preSolve(_ userData: UnsafeRawPointer?, _ contact: OpaquePointer?, _ manifold: UnsafePointer<b2Manifold>?) {
    let listner = Unmanaged<_Physics2DContactListner>.fromOpaque(userData!).takeUnretainedValue()
    listner.preSolve(contact, oldManifold: manifold)
}
