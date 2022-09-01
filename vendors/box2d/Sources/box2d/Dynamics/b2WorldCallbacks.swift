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



/// Joints and fixtures are destroyed when their associated
/// body is destroyed. Implement this listener so that you
/// may nullify references to these joints and shapes.
public protocol b2DestructionListener {
    /// Called when any joint is about to be destroyed due
    /// to the destruction of one of its attached bodies.
    func sayGoodbye(_ joint: b2Joint)
    
    /// Called when any fixture is about to be destroyed due
    /// to the destruction of its parent body.
    func sayGoodbye(_ fixture: b2Fixture)
}

/// Implement this class to provide collision filtering. In other words, you can implement
/// this class if you want finer control over contact creation.
open class b2ContactFilter {
    /// Return true if contact calculations should be performed between these two shapes.
    /// @warning for performance reasons this is only called when the AABBs begin to overlap.
    func shouldCollide(_ fixtureA: b2Fixture, _ fixtureB: b2Fixture) -> Bool {
        let filterA = fixtureA.filterData
        let filterB = fixtureB.filterData
        
        if filterA.groupIndex == filterB.groupIndex && filterA.groupIndex != 0 {
            return filterA.groupIndex > 0
        }
        
        let collide = (filterA.maskBits & filterB.categoryBits) != 0 && (filterA.categoryBits & filterB.maskBits) != 0
        return collide
    }
}

/// Contact impulses for reporting. Impulses are used instead of forces because
/// sub-step forces may approach infinity for rigid body collisions. These
/// match up one-to-one with the contact points in b2Manifold.
public struct b2ContactImpulse {
    public var normalImpulses = [b2Float](repeating: 0, count: b2_maxManifoldPoints)
    public var tangentImpulses = [b2Float](repeating: 0, count: b2_maxManifoldPoints)
    public var count = 0
}

/// things like sounds and game logic. You can also get contact results by
/// traversing the contact lists after the time step. However, you might miss
/// some contacts because continuous physics leads to sub-stepping.
/// Additionally you may receive multiple callbacks for the same contact in a
/// single time step.
/// You should strive to make your callbacks efficient because there may be
/// many callbacks per time step.
/// @warning You cannot create/destroy Box2D entities inside these callbacks.
public protocol b2ContactListener {
    /// Called when two fixtures begin to touch.
    func beginContact(_ contact: b2Contact)
    
    /// Called when two fixtures cease to touch.
    func endContact(_ contact: b2Contact)
    
    /// This is called after a contact is updated. This allows you to inspect a
    /// contact before it goes to the solver. If you are careful, you can modify the
    /// contact manifold (e.g. disable contact).
    /// A copy of the old manifold is provided so that you can detect changes.
    /// Note: this is called only for awake bodies.
    /// Note: this is called even when the number of contact points is zero.
    /// Note: this is not called for sensors.
    /// Note: if you set the number of contact points to zero, you will not
    /// get an EndContact callback. However, you may get a BeginContact callback
    /// the next step.
    func preSolve(_ contact: b2Contact, oldManifold: b2Manifold)
    
    /// This lets you inspect a contact after the solver is finished. This is useful
    /// for inspecting impulses.
    /// Note: the contact manifold does not include time of impact impulses, which can be
    /// arbitrarily large if the sub-step is small. Hence the impulse is provided explicitly
    /// in a separate data structure.
    /// Note: this is only called for contacts that are touching, solid, and awake.
    func postSolve(_ contact: b2Contact, impulse: b2ContactImpulse)
}

open class b2DefaultContactListener : b2ContactListener {
    open func beginContact(_ contact : b2Contact) {}
    open func endContact(_ contact: b2Contact) {}
    open func preSolve(_ contact: b2Contact, oldManifold: b2Manifold) {}
    open func postSolve(_ contact: b2Contact, impulse: b2ContactImpulse) {}
}

/// Callback class for AABB queries.
/// See b2World::Query
public protocol b2QueryCallback {
    /**
     Called for each fixture found in the query AABB.
     
     - returns: false to terminate the query.
     */
    func reportFixture(_ fixture: b2Fixture) -> Bool
}

public typealias b2QueryCallbackFunction = (_ fixture: b2Fixture) -> Bool

class b2QueryCallbackProxy: b2QueryCallback {
    var callback: b2QueryCallbackFunction
    init(callback: @escaping b2QueryCallbackFunction) {
        self.callback = callback
    }
    func reportFixture(_ fixture: b2Fixture) -> Bool {
        return self.callback(fixture)
    }
}

/// Callback class for ray casts.
/// See b2World::RayCast
public protocol b2RayCastCallback {
    /**
     Called for each fixture found in the query. You control how the ray cast
     proceeds by returning a float:
     return -1: ignore this fixture and continue
     return 0: terminate the ray cast
     return fraction: clip the ray to this point
     return 1: don't clip the ray and continue
     
     - parameter fixture: the fixture hit by the ray
     - parameter point: the point of initial intersection
     - parameter normal: the normal vector at the point of intersection
     
     - returns: -1 to filter, 0 to terminate, fraction to clip the ray for closest hit, 1 to continue
     */
    func reportFixture(_ fixture: b2Fixture, point: b2Vec2, normal: b2Vec2, fraction: b2Float) -> b2Float
}

public typealias b2RayCastCallbackFunction = (_ fixture: b2Fixture, _ point: b2Vec2, _ normal: b2Vec2, _ fraction: b2Float) -> b2Float

class b2RayCastCallbackProxy: b2RayCastCallback {
    var callback: b2RayCastCallbackFunction
    init(callback: @escaping b2RayCastCallbackFunction) {
        self.callback = callback
    }
    func reportFixture(_ fixture: b2Fixture, point: b2Vec2, normal: b2Vec2, fraction: b2Float) -> b2Float {
        return self.callback(fixture, point, normal, fraction)
    }
}
