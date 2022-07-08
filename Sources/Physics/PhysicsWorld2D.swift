//
//  PhysicsWorld2D.swift
//  
//
//  Created by v.prusakov on 7/6/22.
//

import box2d
import Math

public struct Body2D {
    unowned let world: PhysicsWorld2D
    
    var ref: UnsafeMutablePointer<b2Body>?
    
    public func applyForce(force: Vector2, point: Vector2, wake: Bool) {
        var force = force.b2Vec
        var point = point.b2Vec
        ref?.pointee.ApplyForce(&force, &point, wake)
    }
}

public struct Body2DContact {
    let bodyA: Body2D
    let bodyB: Body2D
    let collisionImpulse: Float
}

@frozen
public enum BodyType {
    case `static`
    case `dynamic`
    case kinematic
}

public struct Body2DDefinition {
    
    public var type: BodyType = .static
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

public protocol PhysicsWorld2DContactDelegate: AnyObject {
    func physicsWorld(_ world: PhysicsWorld2D, didBeginContact: Body2DContact)
    func physicsWorld(_ world: PhysicsWorld2D, didEndContact: Body2DContact)
}

public final class PhysicsWorld2D {
    
    private var world: b2World
    
    public weak var delegate: PhysicsWorld2DContactDelegate?
    
    public var velocityIterations: Int32 = 6
    public var positionIterations: Int32 = 2
    
    public var gravity: Vector2 {
        get {
            let vec = self.world.GetGravity()
            return [vec.x, vec.y]
        }
        
        set {
            var vec = b2Vec2(newValue.x, newValue.y)
            self.world.SetGravity(&vec)
        }
    }
    
    public init(gravity: Vector2 = .zero) {
        var vec = gravity.b2Vec
        self.world = b2World(&vec)
    }
    
    public func updateSimulation(_ delta: Float) {
        self.world.Step(delta, self.velocityIterations, self.positionIterations)
        
        var unmanaged = Unmanaged.passRetained(self).toOpaque()
        var listner = b2_swift_ContactListener(unmanaged)
        listner.m_BeginContact = b2_ContactListner_BeginContact
        listner.m_EndContact = b2_ContactListner_EndContact
        listner.m_Deconstructor = b2_ContactListner_Deconstructor
    }
    
    public func createBody(definition: Body2DDefinition) -> Body2D {
        var body2D = Body2D(world: self)
        
        var body = b2BodyDef()
        body.angle = definition.angle
        body.position = definition.position.b2Vec
        body.type = definition.type.b2Type
        body.gravityScale = definition.gravityScale
        body.enabled = definition.isEnabled
        body.allowSleep = definition.allowSleep
        body.fixedRotation = definition.fixedRotation
        body.bullet = definition.bullet
        body.awake = definition.awake
        
        body.angularDamping = definition.angularDamping
        body.angularVelocity = definition.angularVelocity
        body.linearDamping = definition.linearDamping
        body.linearVelocity = definition.linearVelocity.b2Vec
        
        let ref = self.world.CreateBody(&body)
        body2D.ref = ref
        
        return body2D
    }
    
    public func destroyBody(_ body: Body2D) {
        self.world.DestroyBody(body.ref)
    }
}

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

extension BodyType {
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
            fatalError("Not supported type")
        }
    }
}

// This functions help us to work with contact listner

private func b2_ContactListner_BeginContact(
    _ contact: UnsafeMutablePointer<b2Contact>!,
    _ userObject: UnsafeMutableRawPointer!
) {
    let world = Unmanaged<PhysicsWorld2D>.fromOpaque(userObject).takeUnretainedValue()
    
    var contact = contact.pointee
    let manifold: UnsafePointer<b2Manifold>! = contact.GetManifold()
    let impulse = manifold.pointee.points.0.normalImpulse
    
    let bodyA = Body2D(world: world, ref: contact.GetFixtureA().pointee.GetBody())
    let bodyB = Body2D(world: world, ref: contact.GetFixtureB().pointee.GetBody())
    
    let physicsContact = Body2DContact(
        bodyA: bodyA,
        bodyB: bodyB,
        collisionImpulse: impulse
    )
    world.delegate?.physicsWorld(world, didEndContact: physicsContact)
}

private func b2_ContactListner_EndContact(
    _ contact: UnsafeMutablePointer<b2Contact>!,
    _ userObject: UnsafeMutableRawPointer!
) {
    let world = Unmanaged<PhysicsWorld2D>.fromOpaque(userObject).takeUnretainedValue()
    
    var contact = contact.pointee
    let manifold: UnsafePointer<b2Manifold>! = contact.GetManifold()
    let impulse = manifold.pointee.points.0.normalImpulse
    
    let bodyA = Body2D(world: world, ref: contact.GetFixtureA().pointee.GetBody())
    let bodyB = Body2D(world: world, ref: contact.GetFixtureB().pointee.GetBody())
    
    let physicsContact = Body2DContact(
        bodyA: bodyA,
        bodyB: bodyB,
        collisionImpulse: impulse
    )
    
    world.delegate?.physicsWorld(world, didEndContact: physicsContact)
}

private func b2_ContactListner_Deconstructor(
    _ userObject: UnsafeMutableRawPointer!
) {
    Unmanaged<PhysicsWorld2D>.fromOpaque(userObject).release()
}

