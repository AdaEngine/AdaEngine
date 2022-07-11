//
//  PhysicsWorld2D.swift
//  
//
//  Created by v.prusakov on 7/6/22.
//

import box2d
import Math

// TODO: Add hashable and equatable and resource
public final class Shape2DResource {
    
    let fixtureDef: b2FixtureDef
    
    init(fixtureDef: b2FixtureDef) {
        self.fixtureDef = fixtureDef
    }
    
    public static func generateCircle(radius: Float) -> Shape2DResource {
        let shape = b2CircleShape()
        shape.radius = radius
        
        let fixtureDef = b2FixtureDef()
        fixtureDef.shape = shape
        
        return Shape2DResource(fixtureDef: fixtureDef)
    }
    
    public static func generateBox(width: Float, height: Float) -> Shape2DResource {
        let shape = b2PolygonShape()
        shape.setAsBox(halfWidth: width, halfHeight: height)
        
        let fixtureDef = b2FixtureDef()
        fixtureDef.shape = shape
        
        return Shape2DResource(fixtureDef: fixtureDef)
    }
    
    public static func generateBox(width: Float, height: Float, center: Vector2, angle: Float) -> Shape2DResource {
        let shape = b2PolygonShape()
        shape.setAsBox(halfWidth: width, halfHeight: height, center: center.b2Vec, angle: angle)
        
        let fixtureDef = b2FixtureDef()
        fixtureDef.shape = shape
        
        return Shape2DResource(fixtureDef: fixtureDef)
    }
    
    public static func generatePolygon(vertices: [Vector2]) -> Shape2DResource {
        let shape = b2PolygonShape()
        shape.set(vertices: unsafeBitCast(vertices, to: [b2Vec2].self))
        
        let fixtureDef = b2FixtureDef()
        fixtureDef.shape = shape
        
        return Shape2DResource(fixtureDef: fixtureDef)
    }
}

public struct PhysicsBody2DComponent: Component {
    
    public var mode: PhysicsBodyMode
    public var filter: CollisionFilter = CollisionFilter()
    
    internal var runtimeBody: Body2D?
    public var shapes: [Shape2DResource]
    public var density: Float
    public var mass: Float
    
    public init(shapes: [Shape2DResource], density: Float, mode: PhysicsBodyMode = .dynamic) {
        self.mode = mode
        self.shapes = shapes
        self.density = density
        self.mass = 0
    }
    
    public init(shapes: [Shape2DResource], mass: Float, mode: PhysicsBodyMode = .dynamic) {
        self.mode = mode
        self.shapes = shapes
        self.density = 0
        self.mass = mass
    }
    
    public func applyForce(force: Vector2, point: Vector2, wake: Bool) {
        self.runtimeBody?.ref.applyForce(force.b2Vec, point: point.b2Vec, wake: wake)
    }
    
    public func applyLinearImpulse(_ impulse: Vector2, point: Vector2, wake: Bool) {
        self.runtimeBody?.ref.applyLinearImpulse(impulse.b2Vec, point: point.b2Vec, wake: wake)
    }
}

public struct CollisionFilter {
    public var categoryBitMask: CollisionGroup = .default
    public var collisionBitMask: CollisionGroup = .default
    
    public init(
        categoryBitMask: CollisionGroup = .default,
        collisionBitMask: CollisionGroup = .default
    ) {
        self.categoryBitMask = categoryBitMask
        self.collisionBitMask = collisionBitMask
    }
}

public struct Collision2DComponent: Component {
    
    internal var runtimeBody: Body2D?
    public var shapes: [Shape2DResource] = []
    public var mode: PhysicsBodyMode
    public var filter: CollisionFilter
    
    public init(
        shapes: [Shape2DResource],
        mode: PhysicsBodyMode = .static,
        filter: CollisionFilter = CollisionFilter()
    ) {
        self.mode = mode
        self.shapes = shapes
        self.filter = filter
    }
}

public struct CollisionGroup: OptionSet {
    public var rawValue: UInt16
    
    public init(rawValue: UInt16) {
        self.rawValue = rawValue
    }
    
    public static var `default` = CollisionGroup(rawValue: .max)
}

public final class Body2D {
    unowned let world: PhysicsWorld2D
    let ref: b2Body
    let entity: Entity
    
    internal init(world: PhysicsWorld2D, ref: b2Body, entity: Entity) {
        self.world = world
        self.ref = ref
        self.entity = entity
    }
    
    func addFixture(for shape: Shape2DResource) {
        self.ref.createFixture(shape.fixtureDef)
    }
}

@frozen
public enum PhysicsBodyMode {
    case `static`
    case `dynamic`
    case kinematic
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

public enum CollisionEvent2D {
    public struct Began: Event {
        let entityA: Entity
        let entityB: Entity
        
        let collisionImpulse: Float
    }
    
    public struct Ended: Event {
        let entityA: Entity
        let entityB: Entity
        
        let collisionImpulse: Float
    }
}

public final class PhysicsWorld2D {
    
    private var world: b2World
    
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
    init(gravity: Vector2 = [0, -9.8]) {
        self.world = b2World(gravity: gravity.b2Vec)
        let contactListner = Physics2DContactListner()
        self.world.setContactListener(contactListner)
    }
    
    public func updateSimulation(_ delta: Float) {
        self.world.step(
            timeStep: delta,
            velocityIterations: self.velocityIterations,
            positionIterations: self.positionIterations
        )
    }
    
    func createBody(definition: Body2DDefinition, for entity: Entity) -> Body2D {
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
    
    public func destroyBody(_ body: Body2D) {
        self.world.destroyBody(body.ref)
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
        default:
            fatalError("Not supported type")
        }
    }
}

// MARK: b2ContactListener

final class Physics2DContactListner: b2ContactListener {
    
    func beginContact(_ contact: b2Contact) {
        
        let bodyA = contact.fixtureA.body.userData as! Body2D
        let bodyB = contact.fixtureB.body.userData as! Body2D
        
        let event = CollisionEvent2D.Began(
            entityA: bodyA.entity,
            entityB: bodyB.entity,
            collisionImpulse: 0
        )
        
        EventManager.default.send(event)
    }
    
    func endContact(_ contact: b2Contact) {
        let bodyA = contact.fixtureA.body.userData as! Body2D
        let bodyB = contact.fixtureB.body.userData as! Body2D
        
        let event = CollisionEvent2D.Began(
            entityA: bodyA.entity,
            entityB: bodyB.entity,
            collisionImpulse: 0
        )
        
        EventManager.default.send(event)
    }
    
    func postSolve(_ contact: b2Contact, impulse: b2ContactImpulse) {
        return
    }
    
    func preSolve(_ contact: b2Contact, oldManifold: b2Manifold) {
        return
    }
}


//// This functions help us to work with contact listner
//
//private func b2_ContactListner_BeginContact(
//    _ contact: UnsafeMutablePointer<b2Contact>!,
//    _ userObject: UnsafeMutableRawPointer!
//) {
//    let world = Unmanaged<PhysicsWorld2D>.fromOpaque(userObject).takeUnretainedValue()
//
//    var contact = contact.pointee
//    let manifold: UnsafePointer<b2Manifold>! = contact.GetManifold()
//    let impulse = manifold.pointee.points.0.normalImpulse
//
//    let bodyA = Body2D(world: world, ref: contact.GetFixtureA().pointee.GetBody())
//    let bodyB = Body2D(world: world, ref: contact.GetFixtureB().pointee.GetBody())
//
//    let physicsContact = Body2DContact(
//        bodyA: bodyA,
//        bodyB: bodyB,
//        collisionImpulse: impulse
//    )
//    world.delegate?.physicsWorld(world, didEndContact: physicsContact)
//}
//
//private func b2_ContactListner_EndContact(
//    _ contact: UnsafeMutablePointer<b2Contact>!,
//    _ userObject: UnsafeMutableRawPointer!
//) {
//    let world = Unmanaged<PhysicsWorld2D>.fromOpaque(userObject).takeUnretainedValue()
//
//    var contact = contact.pointee
//    let manifold: UnsafePointer<b2Manifold>! = contact.GetManifold()
//    let impulse = manifold.pointee.points.0.normalImpulse
//
//    let bodyA = Body2D(world: world, ref: contact.GetFixtureA().pointee.GetBody())
//    let bodyB = Body2D(world: world, ref: contact.GetFixtureB().pointee.GetBody())
//
//    let physicsContact = Body2DContact(
//        bodyA: bodyA,
//        bodyB: bodyB,
//        collisionImpulse: impulse
//    )
//
//    world.delegate?.physicsWorld(world, didEndContact: physicsContact)
//}
//
//private func b2_ContactListner_Deconstructor(
//    _ userObject: UnsafeMutableRawPointer!
//) {
//    Unmanaged<PhysicsWorld2D>.fromOpaque(userObject).release()
//}
//
