//
//  PhysicsWorld2D.swift
//
//
//  Created by v.prusakov on 7/6/22.
//

import AdaBox2d
import Math

public final class Body2D {
    
    unowned let world: PhysicsWorld2D
    unowned let entity: Entity
//
//    @usableFromInline
//    private(set) var ref: b2Body
    
    internal init(world: PhysicsWorld2D, entity: Entity) {
        self.world = world
//        self.ref = ref
        self.entity = entity
    }
//
//    internal init(world: PhysicsWorld2D, ref: b2Body, entity: Entity) {
//        self.world = world
////        self.ref = ref
//        self.entity = entity
//    }
    
//    @inlinable
//    @inline(__always)
//    func addFixture(for fixtureDef: UnsafePointer<b2FixtureDef>) {
//        self.ref.CreateFixture(fixtureDef)
//    }
//
//    @inlinable
//    @inline(__always)
//    func getPosition() -> Vector2 {
//        return ref.GetPosition().pointee.asVector2
//    }
//
//    @inlinable
//    @inline(__always)
//    func getAngle() -> Float {
//        return self.ref.GetAngle()
//    }
//
//    @inlinable
//    @inline(__always)
//    func getLinearVelocity() -> Vector2 {
//        return self.ref.GetLinearVelocity().pointee.asVector2
//    }
//
//    @inlinable
//    @inline(__always)
//    func getWorldCenter() -> Vector2 {
//        return self.ref.GetWorldCenter().pointee.asVector2
//    }
//
//    @inlinable
//    @inline(__always)
//    func getFixtureList() -> b2Fixture? {
//        return self.ref.GetFixtureListMutating()
//    }
//
//    @inlinable
//    @inline(__always)
//    func setTransform(position: Vector2, angle: Float) {
//        self.ref.SetTransform(position.b2Vec, angle)
//    }
//
//    /// Set the linear velocity of the center of mass.
//    @inlinable
//    @inline(__always)
//    func setLinearVelocity(_ vector: Vector2) {
//        self.ref.SetLinearVelocity(vector.b2Vec)
//    }
//
//    /// Apply a force at a world point. If the force is not applied at the center of mass, it will generate a torque and affect the angular velocity. This wakes up the body.
//    @inlinable
//    @inline(__always)
//    func applyForce(force: Vector2, point: Vector2, wake: Bool) {
//        self.ref.ApplyForce(force.b2Vec, point.b2Vec, wake)
//    }
//
//    /// Apply a force to the center of mass. This wakes up the body.
//    @inlinable
//    @inline(__always)
//    func applyForceToCenter(_ force: Vector2, wake: Bool) {
//        self.ref.ApplyForceToCenter(force.b2Vec, wake)
//    }
//
//    /// Apply an impulse at a point. This immediately modifies the velocity.
//    /// It also modifies the angular velocity if the point of application is not at the center of mass. This wakes up the body.
//    @inlinable
//    @inline(__always)
//    func applyLinearImpulse(_ impulse: Vector2, point: Vector2, wake: Bool) {
//        self.ref.ApplyLinearImpulse(impulse.b2Vec, point.b2Vec, wake)
//    }
//
//    /// Apply a torque. This affects the angular velocity without affecting the linear velocity of the center of mass. This wakes up the body.
//    @inlinable
//    @inline(__always)
//    func applyTorque(_ torque: Float, wake: Bool) {
//        self.ref.ApplyTorque(torque, wake)
//    }
//
//    /// Get the world linear velocity of a world point attached to this body.
//    /// - Parameter worldPoint: point in world coordinates.
//    /// - Returns: The world velocity of a point or zero if entity not attached to Physics2DWorld.
//    @inlinable
//    @inline(__always)
//    func getLinearVelocityFromWorldPoint(_ worldPoint: Vector2) -> Vector2 {
//        self.ref.GetLinearVelocityFromWorldPoint(worldPoint.b2Vec).asVector2
//    }
//
//    /// Get the world velocity of a local point.
//    /// - Parameter localPoint: point in local coordinates.
//    /// - Returns: The world velocity of a point or zero if entity not attached to Physics2DWorld.
//    @inlinable
//    @inline(__always)
//    func getLinearVelocityFromLocalPoint(_ localPoint: Vector2) -> Vector2 {
//        self.ref.GetLinearVelocityFromLocalPoint(localPoint.b2Vec).asVector2
//    }
}

public struct Body2DDefinition {
    public var bodyMode: PhysicsBodyMode = .static
    public var position: Vector2 = .zero
    public var angle: Float = 0
    public var gravityScale: Float = 1
    public var linearVelocity: Vector2 = .zero
    
    public var angularVelocity: Float = 0
    public var linearDamping: Float = 0.01
    public var angularDamping: Float = 0.05
    public var allowSleep: Bool = true
    public var awake: Bool = true
    public var fixedRotation: Bool = false
    public var bullet: Bool = false
    public var isEnabled = true
}
//
public final class PhysicsWorld2D/*: Codable*/ {
    
    enum CodingKeys: CodingKey {
        case velocityIterations
        case positionIterations
        case gravity
    }
    
//    private var world: b2World
    
    weak var scene: Scene?
    
    public var velocityIterations: Int = 6
    public var positionIterations: Int = 2
    
//    public var gravity: Vector2 {
//        get {
//            return self.world.GetGravity().asVector2
//        }
//
//        set {
//            self.world.SetGravity(newValue.b2Vec)
//        }
//    }
    
//    public convenience init(from decoder: Decoder) throws {
//        let container = try decoder.container(keyedBy: CodingKeys.self)
//        let gravity = try container.decode(Vector2.self, forKey: .gravity)
//
//        self.init(gravity: gravity)
//
//        self.velocityIterations = try container.decode(Int.self, forKey: .velocityIterations)
//        self.positionIterations = try container.decode(Int.self, forKey: .positionIterations)
//    }
    
//    public func encode(to encoder: Encoder) throws {
//        var container = encoder.container(keyedBy: CodingKeys.self)
//        try container.encode(self.gravity, forKey: .gravity)
//        try container.encode(self.velocityIterations, forKey: .velocityIterations)
//        try container.encode(self.positionIterations, forKey: .positionIterations)
//    }
    
//    let contactListner = _Physics2DContactListner()
    
    /// - Parameter gravity: default gravity is 9.8.
//    init(gravity: Vector2 = [0, -9.81]) {
//        self.world = ada.b2World_create(gravity.b2Vec)
//        self.world.SetContactListener(self.contactListner.contactListener)
//    }
//    
//    deinit {
//        ada.b2World_delete(self.world)
//    }
//    
//    internal func updateSimulation(_ delta: Float) {
//        self.world.Step(
//            delta, /* timeStep */
//            int32(self.velocityIterations), /* velocityIterations */
//            int32(self.positionIterations) /* positionIterations */
//        )
//    }
//    
//    public func createBody(definition: Body2DDefinition, for entity: Entity) -> Body2D {
//        var bodyDef = b2BodyDef()
//        bodyDef.angle = definition.angle
//        bodyDef.position = definition.position.b2Vec
//        bodyDef.type = definition.bodyMode.b2Type
//        bodyDef.gravityScale = definition.gravityScale
//        bodyDef.allowSleep = definition.allowSleep
//        bodyDef.fixedRotation = definition.fixedRotation
//        bodyDef.bullet = definition.bullet
//        bodyDef.awake = definition.awake
//        
//        bodyDef.angularDamping = definition.angularDamping
//        bodyDef.angularVelocity = definition.angularVelocity
//        bodyDef.linearDamping = definition.linearDamping
//        bodyDef.linearVelocity = definition.linearVelocity.b2Vec
//        
//        let ref = self.world.CreateBody(&bodyDef)!
//        let body2d = Body2D(world: self, ref: ref, entity: entity)
//        let pointer = Unmanaged.passRetained(body2d).toOpaque()
//        
//        ref.GetUserDataMutating().pointee.pointer = UInt(bitPattern: pointer)
//        
//        return body2d
//    }
//    
//    public func createJoint(_ jointPtr: UnsafePointer<b2JointDef>) -> OpaquePointer {
//        self.world.CreateJoint(jointPtr)
//    }
//    
//    public func destroyJoint(_ joint: OpaquePointer) {
//        self.world.DestroyJoint(joint)
//    }
//    
//    public func destroyBody(_ body: Body2D) {
//        self.world.DestroyBody(body.ref)
//    }
//    
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

// swiftlint:disable:next type_name

//final class _Physics2DContactListner {
//
//    typealias B2Contact = @convention(c) (UnsafeRawPointer?, b2Contact?) -> Void
//
//    lazy var contactListener: UnsafeMutablePointer<b2ContactListener> = {
//        let ptr = Unmanaged.passUnretained(self).toOpaque()
//        let contactListner = ada.ContactListener2D_create(UnsafeRawPointer(ptr))!
//        contactListner.pointee.m_BeginContact = _beginContact(_:_:) as B2Contact
//        contactListner.pointee.m_EndContact = _endContact(_:_:) as B2Contact
//        return ada.b2ContactListener_unsafeCast(contactListner)!
//    }()
//
//    deinit {
//        self.contactListener.deallocate()
//    }
//
//    func beginContact(_ contact: b2Contact?) {
//        guard let contact else {
//            return
//        }
//
//        let bodyAPtrInt = contact.GetFixtureA().GetBody().GetUserData().pointee.pointer
//        let bodyBPtrInt = contact.GetFixtureA().GetBody().GetUserData().pointee.pointer
//
//        guard let bodyAPtr = UnsafeRawPointer(bitPattern: bodyAPtrInt),
//              let bodyBPtr = UnsafeRawPointer(bitPattern: bodyBPtrInt) else {
//            return
//        }
//
//        let bodyA = Unmanaged<Body2D>.fromOpaque(bodyAPtr).takeUnretainedValue()
//        let bodyB = Unmanaged<Body2D>.fromOpaque(bodyBPtr).takeUnretainedValue()
//
//        // FIXME: We should get correct impulse of contact
//        let impulse = contact.GetManifold().pointee.points.0.normalImpulse
//
//        let event = CollisionEvents.Began(
//            entityA: bodyA.entity,
//            entityB: bodyB.entity,
//            impulse: impulse
//        )
//
//        bodyA.world.scene?.eventManager.send(event)
//    }
//
//    func endContact(_ contact: b2Contact?) {
//        guard let contact else {
//            return
//        }
//
//        let bodyAPtrInt = contact.GetFixtureA().GetBody().GetUserData().pointee.pointer
//        let bodyBPtrInt = contact.GetFixtureA().GetBody().GetUserData().pointee.pointer
//
//        guard let bodyAPtr = UnsafeRawPointer(bitPattern: bodyAPtrInt),
//              let bodyBPtr = UnsafeRawPointer(bitPattern: bodyBPtrInt) else {
//            return
//        }
//
//        let bodyA = Unmanaged<Body2D>.fromOpaque(bodyAPtr).takeUnretainedValue()
//        let bodyB = Unmanaged<Body2D>.fromOpaque(bodyBPtr).takeUnretainedValue()
//
//        let event = CollisionEvents.Ended(
//            entityA: bodyA.entity,
//            entityB: bodyB.entity
//        )
//
//        bodyA.world.scene?.eventManager.send(event)
//    }
//
//    func postSolve(_ contact: b2Contact?, impulse: UnsafePointer<b2ContactImpulse>?) {
//        return
//    }
//
//    func preSolve(_ contact: b2Contact?, oldManifold: UnsafePointer<b2Manifold>?) {
//        return
//    }
//}
//
//private func _beginContact(_ userData: UnsafeRawPointer?, _ contact: b2Contact?) {
//    let listner = Unmanaged<_Physics2DContactListner>.fromOpaque(userData!).takeUnretainedValue()
//    listner.beginContact(contact)
//}
//
//private func _endContact(_ userData: UnsafeRawPointer?, _ contact: b2Contact?) {
//    let listner = Unmanaged<_Physics2DContactListner>.fromOpaque(userData!).takeUnretainedValue()
//    listner.endContact(contact)
//}
//
//func _postSolve(_ userData: UnsafeRawPointer?, _ contact: b2Contact?, _ impulse: UnsafePointer<b2ContactImpulse>?) {
//    let listner = Unmanaged<_Physics2DContactListner>.fromOpaque(userData!).takeUnretainedValue()
//    listner.postSolve(contact, impulse: impulse)
//}
//
//func _preSolve(_ userData: UnsafeRawPointer?, _ contact: b2Contact?, _ manifold: UnsafePointer<b2Manifold>?) {
//    let listner = Unmanaged<_Physics2DContactListner>.fromOpaque(userData!).takeUnretainedValue()
//    listner.preSolve(contact, oldManifold: manifold)
//}
