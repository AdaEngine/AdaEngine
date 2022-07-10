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



var b2_defaultFilter = b2ContactFilter()
var b2_defaultListener = b2DefaultContactListener()

// Delegate of b2World.
open class b2ContactManager: b2BroadPhaseWrapper {
    init() {
        m_contactList = nil
        m_contactCount = 0
        m_contactFilter = b2_defaultFilter
        m_contactListener = b2_defaultListener
    }
    
    // Broad-phase callback.
    open func addPair(_ proxyUserDataA: inout b2FixtureProxy, _ proxyUserDataB: inout b2FixtureProxy) {
        let proxyA = proxyUserDataA
        let proxyB = proxyUserDataB
        
        var fixtureA = proxyA.fixture
        var fixtureB = proxyB.fixture
        
        var indexA = proxyA.childIndex
        var indexB = proxyB.childIndex
        
        var bodyA = fixtureA.body
        var bodyB = fixtureB.body
        
        // Are the fixtures on the same body?
        if bodyA === bodyB {
            return
        }
        
        // TODO_ERIN use a hash table to remove a potential bottleneck when both
        // bodies have a lot of contacts.
        // Does a contact already exist?
        var edge = bodyB.getContactList()
        
        while edge != nil {
            if edge!.other === bodyA {
                let fA = edge!.contact.fixtureA
                let fB = edge!.contact.fixtureB
                let iA = edge!.contact.childIndexA
                let iB = edge!.contact.childIndexB
                
                if fA === fixtureA && fB === fixtureB && iA == indexA && iB == indexB {
                    // A contact already exists.
                    return
                }
                
                if fA === fixtureB && fB === fixtureA && iA == indexB && iB == indexA {
                    // A contact already exists.
                    return
                }
            }
            
            edge = edge!.next
        }
        
        // Does a joint override collision? Is at least one body dynamic?
        if bodyB.shouldCollide(bodyA) == false {
            return
        }
        
        // Check user filtering.
        if m_contactFilter != nil && m_contactFilter!.shouldCollide(fixtureA, fixtureB) == false {
            return
        }
        
        // Call the factory.
        let c = b2Contact.create(fixtureA, indexA, fixtureB, indexB)
        if c == nil {
            return
        }
        
        // Contact creation may swap fixtures.
        fixtureA = c!.fixtureA
        fixtureB = c!.fixtureB
        indexA = c!.childIndexA
        indexB = c!.childIndexB
        bodyA = fixtureA.body
        bodyB = fixtureB.body
        
        // Insert into the world.
        c!.m_prev = nil
        c!.m_next = m_contactList
        if m_contactList != nil {
            m_contactList!.m_prev = c
        }
        m_contactList = c
        
        // Connect to island graph.
        
        // Connect to body A
        c!.m_nodeA.contact = c!
        c!.m_nodeA.other = bodyB
        
        c!.m_nodeA.prev = nil
        c!.m_nodeA.next = bodyA.m_contactList
        if bodyA.m_contactList != nil {
            bodyA.m_contactList!.prev = c!.m_nodeA
        }
        bodyA.m_contactList = c!.m_nodeA
        
        // Connect to body B
        c!.m_nodeB.contact = c!
        c!.m_nodeB.other = bodyA
        
        c!.m_nodeB.prev = nil
        c!.m_nodeB.next = bodyB.m_contactList
        if bodyB.m_contactList != nil {
            bodyB.m_contactList!.prev = c!.m_nodeB
        }
        bodyB.m_contactList = c!.m_nodeB
        
        // Wake up the bodies
        if fixtureA.isSensor == false && fixtureB.isSensor == false {
            bodyA.setAwake(true)
            bodyB.setAwake(true)
        }
        
        m_contactCount += 1
    }
    
    func findNewContacts() {
        m_broadPhase.updatePairs(callback: self)
    }
    
    func destroy(_ c: b2Contact) {
        let fixtureA = c.fixtureA
        let fixtureB = c.fixtureB
        let bodyA = fixtureA.body
        let bodyB = fixtureB.body
        
        if m_contactListener != nil && c.isTouching {
            m_contactListener!.endContact(c)
        }
        
        // Remove from the world.
        if c.m_prev != nil {
            c.m_prev!.m_next = c.m_next
        }
        
        if c.m_next != nil {
            c.m_next!.m_prev = c.m_prev
        }
        
        if c === m_contactList {
            m_contactList = c.m_next
        }
        
        // Remove from body 1
        if c.m_nodeA.prev != nil {
            c.m_nodeA.prev!.next = c.m_nodeA.next
        }
        
        if c.m_nodeA.next != nil {
            c.m_nodeA.next!.prev = c.m_nodeA.prev
        }
        
        if c.m_nodeA === bodyA.m_contactList {
            bodyA.m_contactList = c.m_nodeA.next
        }
        
        // Remove from body 2
        if c.m_nodeB.prev != nil {
            c.m_nodeB.prev!.next = c.m_nodeB.next
        }
        
        if c.m_nodeB.next != nil {
            c.m_nodeB.next!.prev = c.m_nodeB.prev
        }
        
        if c.m_nodeB === bodyB.m_contactList {
            bodyB.m_contactList = c.m_nodeB.next
        }
        
        // Call the factory.
        b2Contact.destroy(c)
        m_contactCount -= 1
    }
    
    // This is the top level collision call for the time step. Here
    // all the narrow phase collision is processed for the world
    // contact list.
    func collide() {
        // Update awake contacts.
        var c = m_contactList
        while c != nil {
            let fixtureA = c!.fixtureA
            let fixtureB = c!.fixtureB
            let indexA = c!.childIndexA
            let indexB = c!.childIndexB
            let bodyA = fixtureA.body
            let bodyB = fixtureB.body
            
            // Is this contact flagged for filtering?
            if (c!.m_flags & b2Contact.Flags.filterFlag) != 0 {
                // Should these bodies collide?
                if bodyB.shouldCollide(bodyA) == false {
                    let cNuke = c!
                    c = cNuke.getNext()
                    destroy(cNuke)
                    continue
                }
                
                // Check user filtering.
                if m_contactFilter != nil && m_contactFilter!.shouldCollide(fixtureA, fixtureB) == false {
                    let cNuke = c!
                    c = cNuke.getNext()
                    destroy(cNuke)
                    continue
                }
                
                // Clear the filtering flag.
                c!.m_flags &= ~b2Contact.Flags.filterFlag
            }
            
            let activeA = bodyA.isAwake && bodyA.m_type != b2BodyType.staticBody
            let activeB = bodyB.isAwake && bodyB.m_type != b2BodyType.staticBody
            // At least one body must be awake and it must be dynamic or kinematic.
            if activeA == false && activeB == false {
                c = c!.getNext()
                continue
            }
            
            let proxyIdA = fixtureA.m_proxies[indexA].proxyId
            let proxyIdB = fixtureB.m_proxies[indexB].proxyId
            let overlap = m_broadPhase.testOverlap(proxyIdA: proxyIdA, proxyIdB: proxyIdB)
            
            // Here we destroy contacts that cease to overlap in the broad-phase.
            if overlap == false {
                let cNuke = c!
                c = cNuke.getNext()
                destroy(cNuke)
                continue
            }
            
            // The contact persists.
            c!.update(m_contactListener!)
            c = c!.getNext()
        }
    }
    
    var m_broadPhase = b2BroadPhase()
    open var broadPhase: b2BroadPhase {
        return m_broadPhase
    }
    var m_contactList: b2Contact? = nil // ** owner **
    var m_contactCount: Int = 0
    var m_contactFilter: b2ContactFilter? = b2_defaultFilter
    var m_contactListener: b2ContactListener? = b2_defaultListener
}


