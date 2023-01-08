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
    
    let ref: b2Body
    
    internal init(world: PhysicsWorld2D, ref: b2Body, entity: Entity) {
        self.world = world
        self.ref = ref
        self.entity = entity
    }
    
    func addFixture(for fixtureDef: b2FixtureDef) {
        self.ref.createFixture(fixtureDef)
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

public final class PhysicsWorld2D {
    
    private var world: b2World
    
    weak var scene: Scene?
    
    public var velocityIterations: Int = 6
    public var positionIterations: Int = 2
    
    public var gravity: Vector2 {
        get {
            let vec = self.world.gravity
            return [vec.x, vec.y]
        }
        
        set {
            self.world.setGravity(newValue.b2Vec)
        }
    }
    
    /// - Parameter gravity: default gravity is 9.8.
    init(gravity: Vector2 = [0, -9.81]) {
        self.world = b2World(gravity: gravity.b2Vec)
        let contactListner = _Physics2DContactListner()
        self.world.setContactListener(contactListner)
    }
    
    public func updateSimulation(_ delta: Float) {
        self.world.step(
            timeStep: delta,
            velocityIterations: self.velocityIterations,
            positionIterations: self.positionIterations
        )
    }
    
    public func createBody(definition: Body2DDefinition, for entity: Entity) -> Body2D {
        let body = b2BodyDef()
        body.angle = definition.angle
        body.position = definition.position.b2Vec
        body.type = definition.bodyMode.b2Type
        body.gravityScale = definition.gravityScale
        body.active = definition.isEnabled
        body.allowSleep = definition.allowSleep
        body.fixedRotation = definition.fixedRotation
        body.bullet = definition.bullet
        body.awake = definition.awake
        
        body.angularDamping = definition.angularDamping
        body.angularVelocity = definition.angularVelocity
        body.linearDamping = definition.linearDamping
        body.linearVelocity = definition.linearVelocity.b2Vec
        
        let ref = self.world.createBody(body)
        
        let body2D = Body2D(world: self, ref: ref, entity: entity)
        ref.setUserData(body2D)
        return body2D
    }
    
    public func createJoint(_ def: b2JointDef) -> b2Joint {
        return self.world.createJoint(def)
    }
    
    public func destroyJoint(_ joint: b2Joint) {
        self.world.destroyJoint(joint)
    }
    
    public func destroyBody(_ body: Body2D) {
        self.world.destroyBody(body.ref)
        body.ref.setUserData(nil)
    }
    
}

// MARK: - Casting

extension Vector2 {
    @inline(__always) var b2Vec: b2Vec2 {
        get {
            return unsafeBitCast(self, to: b2Vec2.self)
        }
        
        set {
            self = unsafeBitCast(newValue, to: Vector2.self)
        }
    }
}

extension b2Vec2 {
    var asVector2: Vector2 {
        return unsafeBitCast(self, to: Vector2.self)
    }
}

extension PhysicsBodyMode {
    var b2Type: b2BodyType {
        switch self {
        case .static: return .staticBody
        case .dynamic: return .dynamicBody
        case .kinematic: return .kinematicBody
        }
    }

    init(b2BodyType: b2BodyType) {
        switch b2BodyType {
        case .staticBody: self = .static
        case .dynamicBody: self = .dynamic
        case .kinematicBody: self = .kinematic
        }
    }
}

// MARK: - b2ContactListener

final class _Physics2DContactListner: b2ContactListener {
    
    func beginContact(_ contact: b2Contact) {
        
        let bodyA = contact.fixtureA.body.userData as! Body2D
        let bodyB = contact.fixtureB.body.userData as! Body2D
        
        // FIXME: We should get correct impulse of contact
        let impulse = contact.manifold.points.first?.normalImpulse
        
        let event = CollisionEvent.Began(
            entityA: bodyA.entity,
            entityB: bodyB.entity,
            impulse: impulse ?? 0
        )
        
        bodyA.world.scene?.eventManager.send(event)
    }
    
    func endContact(_ contact: b2Contact) {
        let bodyA = contact.fixtureA.body.userData as! Body2D
        let bodyB = contact.fixtureB.body.userData as! Body2D
        
        let event = CollisionEvent.Ended(
            entityA: bodyA.entity,
            entityB: bodyB.entity
        )
        
        bodyA.world.scene?.eventManager.send(event)
    }
    
    func postSolve(_ contact: b2Contact, impulse: b2ContactImpulse) {
        return
    }
    
    func preSolve(_ contact: b2Contact, oldManifold: b2Manifold) {
        return
    }
}
