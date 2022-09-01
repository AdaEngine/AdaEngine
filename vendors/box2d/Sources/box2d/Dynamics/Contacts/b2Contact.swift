/**
 Copyright (c) 2006-2014 Erin Catto http://www.box2d.org
 Copyright (c) 2015 - Yohei Yoshihara
 
 This software is provided 'as-is', without any express or implied
 warranty.  In no event will the authors be held liable for any damages
 arising from the use of this software.
 
 Permission is granted to anyone to use this software for any purpose,
 including commercial applications, and to alter it and redistribute it
 freely, subject to the following restrictions:
 
 1. The origin of this software must not be misrepresented; you must not
 claim that you wrote the original software. If you use this software
 in a product, an acknowledgment in the product documentation would be
 appreciated but is not required.
 
 2. Altered source versions must be plainly marked as such, and must not be
 misrepresented as being the original software.
 
 3. This notice may not be removed or altered from any source distribution.
 
 This version of box2d was developed by Yohei Yoshihara. It is based upon
 the original C++ code written by Erin Catto.
 */

import Foundation


/// Friction mixing law. The idea is to allow either fixture to drive the restitution to zero.
/// For example, anything slides on ice.
public func b2MixFriction(_ friction1 : b2Float, friction2 : b2Float) -> b2Float {
    return sqrt(friction1 * friction2)
}

/// Restitution mixing law. The idea is allow for anything to bounce off an inelastic surface.
/// For example, a superball bounces on anything.
public func b2MixRestitution(_ restitution1 : b2Float, restitution2 : b2Float) -> b2Float {
    return restitution1 > restitution2 ? restitution1 : restitution2
}

typealias b2ContactCreateFcn = (_ fixtureA: b2Fixture, _ indexA: Int, _ fixtureB: b2Fixture, _ indexB: Int) -> b2Contact
typealias b2ContactDestroyFcn = (_ contact: b2Contact) -> Void

public struct b2ContactRegister {
    var createFcn: b2ContactCreateFcn? = nil
    var destroyFcn: b2ContactDestroyFcn? = nil
    var primary: Bool = false
}

struct b2ContactRegisters {
    let rows: b2ShapeType
    let columns: b2ShapeType
    var grid : [b2ContactRegister]
    init(_ rows: b2ShapeType, _ columns: b2ShapeType) {
        self.rows = rows
        self.columns = columns
        self.grid = [b2ContactRegister](repeating: b2ContactRegister(), count: rows.rawValue * columns.rawValue)
    }
    subscript(row: b2ShapeType, column: b2ShapeType) -> b2ContactRegister {
        get {
            return grid[(row.rawValue * columns.rawValue) + column.rawValue]
        }
        set {
            grid[(row.rawValue * columns.rawValue) + column.rawValue] = newValue
        }
    }
}

/// A contact edge is used to connect bodies and contacts together
/// in a contact graph where each body is a node and each contact
/// is an edge. A contact edge belongs to a doubly linked list
/// maintained in each attached body. Each contact has two contact
/// nodes, one for each attached body.
open class b2ContactEdge {
    init(contact: b2Contact) {
        self.contact = contact
    }
    var other: b2Body!  = nil      ///< provides quick access to the other body attached.
    unowned var contact: b2Contact ///< the contact ** parent **
    var prev: b2ContactEdge? = nil ///< the previous contact edge in the body's contact list
    var next: b2ContactEdge? = nil ///< the next contact edge in the body's contact list
}

/// AABB in the broad-phase (except if filtered). Therefore a contact object may exist
/// that has no contact points.
open class b2Contact {
    
    /// Get the contact manifold. Do not modify the manifold unless you understand the
    /// internals of Box2D.
    open var manifold: b2Manifold {
        return m_manifold
    }
    
    /// Get the world manifold.
    open var worldManifold: b2WorldManifold {
        let bodyA = m_fixtureA.body
        let bodyB = m_fixtureB.body
        let shapeA = m_fixtureA.shape
        let shapeB = m_fixtureB.shape
        
        let worldManifold = b2WorldManifold()
        worldManifold.initialize(manifold: m_manifold,
                                 transformA: bodyA.transform, radiusA: shapeA.m_radius,
                                 transformB: bodyB.transform, radiusB: shapeB.m_radius)
        return worldManifold
    }
    
    /// Is this contact touching?
    open var isTouching: Bool {
        return (m_flags & Flags.touchingFlag) == Flags.touchingFlag
    }
    
    /// Enable/disable this contact. This can be used inside the pre-solve
    /// contact listener. The contact is only disabled for the current
    /// time step (or sub-step in continuous collisions).
    open func setEnabled(_ flag: Bool) {
        if flag {
            m_flags |= Flags.enabledFlag
        }
        else {
            m_flags &= ~Flags.enabledFlag
        }
    }
    
    /// Has this contact been disabled?
    open var isEnabled: Bool {
        return (m_flags & Flags.enabledFlag) == Flags.enabledFlag
    }
    
    /// Get the next contact in the world's contact list.
    open func getNext() -> b2Contact? {
        return m_next
    }
    
    /// Get fixture A in this contact.
    open var fixtureA: b2Fixture {
        return m_fixtureA
    }
    
    /// Get the child primitive index for fixture A.
    open var childIndexA: Int {
        return m_indexA
    }
    
    /// Get fixture B in this contact.
    open var fixtureB: b2Fixture {
        return m_fixtureB
    }
    //const b2Fixture* GetFixtureB() const
    
    /// Get the child primitive index for fixture B.
    open var childIndexB: Int {
        return m_indexB
    }
    
    /// Override the default friction mixture. You can call this in b2ContactListener::PreSolve.
    /// This value persists until set or reset.
    open func setFriction(_ friction: b2Float) {
        m_friction = friction
    }
    
    /// Get the friction.
    open var friction: b2Float {
        get {
            return m_friction
        }
        set {
            setFriction(newValue)
        }
    }
    
    /// Reset the friction mixture to the default value.
    open func resetFriction() {
        m_friction = b2MixFriction(m_fixtureA.m_friction, friction2: m_fixtureB.m_friction)
    }
    
    /// Override the default restitution mixture. You can call this in b2ContactListener::PreSolve.
    /// The value persists until you set or reset.
    open func setRestitution(_ restitution: b2Float) {
        m_restitution = restitution
    }
    
    /// Get the restitution.
    open var restitution: b2Float {
        get {
            return m_restitution
        }
        set {
            setRestitution(newValue)
        }
    }
    
    /// Reset the restitution to the default value.
    open func resetRestitution() {
        m_restitution = b2MixRestitution(m_fixtureA.m_restitution, restitution2: m_fixtureB.m_restitution)
    }
    
    /// Set the desired tangent speed for a conveyor belt behavior. In meters per second.
    open func setTangentSpeed(_ speed: b2Float) {
        m_tangentSpeed = speed
    }
    
    /// Get the desired tangent speed. In meters per second.
    open var tangentSpeed: b2Float {
        return m_tangentSpeed
    }
    
    /// Evaluate this contact with your own manifold and transforms.
    open func evaluate(_ manifold: inout b2Manifold, _ xfA: b2Transform, _ xfB: b2Transform) {
        fatalError("must override")
    }
    
    // MARK: - private methods
    
    // Flags stored in m_flags
    // Used when crawling contact graph when forming islands.
    struct Flags {
        static let islandFlag		= UInt32(0x0001)
        
        // Set when the shapes are touching.
        static let touchingFlag		= UInt32(0x0002)
        
        // This contact can be disabled (by user)
        static let enabledFlag		= UInt32(0x0004)
        
        // This contact needs filtering because a fixture filter was changed.
        static let filterFlag		= UInt32(0x0008)
        
        // This bullet contact had a TOI event
        static let bulletHitFlag		= UInt32(0x0010)
        
        // This contact has a valid TOI in m_toi
        static let toiFlag			= UInt32(0x0020)
    }
    
    /// Flag this contact for filtering. Filtering will occur the next time step.
    func flagForFiltering() {
        fatalError("must override")
    }
    
    class func addType(_ createFcn: @escaping b2ContactCreateFcn, _ destoryFcn: @escaping b2ContactDestroyFcn, _ type1: b2ShapeType, _ type2: b2ShapeType) {
        assert(0 <= type1.rawValue && type1.rawValue < b2ShapeType.typeCount.rawValue)
        assert(0 <= type2.rawValue && type2.rawValue < b2ShapeType.typeCount.rawValue)
        
        StaticVars.s_registers[type1, type2].createFcn = createFcn
        StaticVars.s_registers[type1, type2].destroyFcn = destoryFcn
        StaticVars.s_registers[type1, type2].primary = true
        
        if type1 != type2 {
            StaticVars.s_registers[type2, type1].createFcn = createFcn
            StaticVars.s_registers[type2, type1].destroyFcn = destoryFcn
            StaticVars.s_registers[type2, type1].primary = false
        }
    }
    class func initializeRegisters() {
        addType(b2CircleContact.create, b2CircleContact.destroy, b2ShapeType.circle, b2ShapeType.circle)
        addType(b2PolygonAndCircleContact.create, b2PolygonAndCircleContact.destroy, b2ShapeType.polygon, b2ShapeType.circle)
        addType(b2PolygonContact.create, b2PolygonContact.destroy, b2ShapeType.polygon, b2ShapeType.polygon)
        addType(b2EdgeAndCircleContact.create, b2EdgeAndCircleContact.destroy, b2ShapeType.edge, b2ShapeType.circle)
        addType(b2EdgeAndPolygonContact.create, b2EdgeAndPolygonContact.destroy, b2ShapeType.edge, b2ShapeType.polygon)
        addType(b2ChainAndCircleContact.create, b2ChainAndCircleContact.destroy, b2ShapeType.chain, b2ShapeType.circle)
        addType(b2ChainAndPolygonContact.create, b2ChainAndPolygonContact.destroy, b2ShapeType.chain, b2ShapeType.polygon)
    }
    class func create(_ fixtureA: b2Fixture, _ indexA: Int, _ fixtureB: b2Fixture, _ indexB: Int) -> b2Contact? {
        if StaticVars.s_initialized == false {
            initializeRegisters()
            StaticVars.s_initialized = true
        }
        
        let type1 = fixtureA.type
        let type2 = fixtureB.type
        
        assert(0 <= type1.rawValue && type1.rawValue < b2ShapeType.typeCount.rawValue)
        assert(0 <= type2.rawValue && type2.rawValue < b2ShapeType.typeCount.rawValue)
        
        let createFcn = StaticVars.s_registers[type1, type2].createFcn
        if createFcn != nil {
            if StaticVars.s_registers[type1, type2].primary {
                return createFcn!(fixtureA, indexA, fixtureB, indexB)
            }
            else {
                return createFcn!(fixtureB, indexB, fixtureA, indexA)
            }
        }
        else {
            return nil
        }
    }
    class func destroy(_ contact: b2Contact) {
        assert(StaticVars.s_initialized == true)
        
        let fixtureA = contact.m_fixtureA
        let fixtureB = contact.m_fixtureB
        
        if contact.m_manifold.pointCount > 0 && fixtureA?.isSensor == false && fixtureB?.isSensor == false {
            fixtureA?.body.setAwake(true)
            fixtureB?.body.setAwake(true)
        }
        
        let typeA = fixtureA?.type
        let typeB = fixtureB?.type
        
        assert(0 <= (typeA?.rawValue)! && (typeB?.rawValue)! < b2ShapeType.typeCount.rawValue)
        assert(0 <= (typeA?.rawValue)! && (typeB?.rawValue)! < b2ShapeType.typeCount.rawValue)
        
        let destroyFcn = StaticVars.s_registers[typeA!, typeB!].destroyFcn
        destroyFcn!(contact)
    }
    
    init(_ fixtureA: b2Fixture, _ indexA: Int, _ fixtureB: b2Fixture, _ indexB: Int) {
        m_flags = Flags.enabledFlag
        
        m_fixtureA = fixtureA
        m_fixtureB = fixtureB
        
        m_indexA = indexA
        m_indexB = indexB
        
        m_manifold.points.removeAll(keepingCapacity: true)
        
        m_prev = nil
        m_next = nil
        
        m_nodeA = b2ContactEdge(contact: self)
        m_nodeA.prev = nil
        m_nodeA.next = nil
        m_nodeA.other = nil
        
        m_nodeB = b2ContactEdge(contact: self)
        m_nodeB.prev = nil
        m_nodeB.next = nil
        m_nodeB.other = nil
        
        m_toiCount = 0
        
        m_friction = b2MixFriction(m_fixtureA.m_friction, friction2: m_fixtureB.m_friction)
        m_restitution = b2MixRestitution(m_fixtureA.m_restitution, restitution2: m_fixtureB.m_restitution)
        
        m_tangentSpeed = 0.0
    }
    
    func update(_ listener: b2ContactListener?) {
        let oldManifold = b2Manifold(copyFrom: m_manifold)
        
        // Re-enable this contact.
        m_flags |= Flags.enabledFlag
        
        var touching = false
        let wasTouching = (m_flags & Flags.touchingFlag) == Flags.touchingFlag
        
        let sensorA = m_fixtureA.isSensor
        let sensorB = m_fixtureB.isSensor
        let sensor = sensorA || sensorB
        
        let bodyA = m_fixtureA.body
        let bodyB = m_fixtureB.body
        let xfA = bodyA.transform
        let xfB = bodyB.transform
        
        // Is this contact a sensor?
        if sensor {
            let shapeA = m_fixtureA.shape
            let shapeB = m_fixtureB.shape
            touching = b2TestOverlap(shapeA: shapeA, indexA: m_indexA,
                                     shapeB: shapeB, indexB: m_indexB,
                                     transformA: xfA, transformB: xfB)
            
            // Sensors don't generate manifolds.
            m_manifold.points.removeAll(keepingCapacity: true)
        }
        else {
            evaluate(&m_manifold, xfA, xfB)
            touching = m_manifold.pointCount > 0
            
            // Match old contact ids to new contact ids and copy the
            // stored impulses to warm start the solver.
            for i in 0 ..< m_manifold.pointCount {
                let mp2 = m_manifold.points[i]
                mp2.normalImpulse = 0.0
                mp2.tangentImpulse = 0.0
                let id2 = mp2.id
                
                for j in 0 ..< oldManifold.pointCount {
                    let mp1 = oldManifold.points[j]
                    
                    if mp1.id == id2 {
                        mp2.normalImpulse = mp1.normalImpulse
                        mp2.tangentImpulse = mp1.tangentImpulse
                        break
                    }
                }
            }
            
            if touching != wasTouching {
                bodyA.setAwake(true)
                bodyB.setAwake(true)
            }
        }
        
        if touching {
            m_flags |= Flags.touchingFlag
        }
        else {
            m_flags &= ~Flags.touchingFlag
        }
        
        if wasTouching == false && touching == true && listener != nil {
            listener!.beginContact(self)
        }
        
        if wasTouching == true && touching == false && listener != nil {
            listener!.endContact(self)
        }
        
        if sensor == false && touching && listener != nil {
            listener!.preSolve(self, oldManifold: oldManifold)
        }
    }
    
    struct StaticVars {
        static var s_registers = b2ContactRegisters(b2ShapeType.typeCount, b2ShapeType.typeCount)
        static var s_initialized : Bool = false
    }
    
    var m_flags: UInt32 = 0
    
    // World pool and list pointers.
    var m_prev: b2Contact? = nil
    var m_next: b2Contact? = nil
    
    // Nodes for connecting bodies.
    var m_nodeA: b2ContactEdge! // ** owner **
    var m_nodeB: b2ContactEdge! // ** owner **
    
    var m_fixtureA: b2Fixture! // ** reference **
    var m_fixtureB: b2Fixture! // ** reference **
    
    var m_indexA: Int = 0
    var m_indexB: Int = 0
    
    var m_manifold = b2Manifold()
    
    var m_toiCount: Int = 0
    var m_toi: b2Float = 0
    
    var m_friction: b2Float = 0
    var m_restitution: b2Float = 0
    
    var m_tangentSpeed: b2Float = 0
}
