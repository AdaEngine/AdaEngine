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



/// The world class manages all physics entities, dynamic simulation,
/// and asynchronous queries. The world also contains efficient memory
/// management facilities.
open class b2World {
    /**
     Construct a world object.
     
     - parameter gravity: the world gravity vector.
     */
    public init(gravity: b2Vec2) {
        m_destructionListener = nil
        m_debugDraw = nil
        
        m_bodyList = nil
        m_jointList = nil
        
        m_bodyCount = 0
        m_jointCount = 0
        
        m_warmStarting = true
        m_continuousPhysics = true
        m_subStepping = false
        
        m_stepComplete = true
        
        m_allowSleep = true
        m_gravity = gravity
        
        m_flags = Flags.clearForces
        
        m_inv_dt0 = 0.0
        
        m_contactManager = b2ContactManager()
    }
    
    /// Destruct the world. All physics entities are destroyed and all heap memory is released.
    deinit {
    }
    
    /// Register a destruction listener. The listener is owned by you and must
    /// remain in scope.
    open func setDestructionListener(_ listener: b2DestructionListener) {
        m_destructionListener = listener
    }
    
    /// Register a contact filter to provide specific control over collision.
    /// Otherwise the default filter is used (b2_defaultFilter). The listener is
    /// owned by you and must remain in scope.
    open func setContactFilter(_ filter: b2ContactFilter) {
        m_contactManager.m_contactFilter = filter
    }
    
    /// Register a contact event listener. The listener is owned by you and must
    /// remain in scope.
    open func setContactListener(_ listener: b2ContactListener) {
        m_contactManager.m_contactListener = listener
    }
    
    /// Register a routine for debug drawing. The debug draw functions are called
    /// inside with b2World::DrawDebugData method. The debug draw object is owned
    /// by you and must remain in scope.
    open func setDebugDraw(_ debugDraw: b2Draw) {
        m_debugDraw = debugDraw
    }
    
    /// Create a rigid body given a definition. No reference to the definition
    /// is retained.
    /// @warning This function is locked during callbacks.
    open func createBody(_ def: b2BodyDef) -> b2Body {
        assert(isLocked == false)
        if isLocked {
            fatalError("world is locked")
        }
        
        let b = b2Body(def, self)
        
        // Add to world doubly linked list.
        b.m_prev = nil
        b.m_next = m_bodyList
        if m_bodyList != nil {
            m_bodyList!.m_prev = b
        }
        m_bodyList = b
        m_bodyCount += 1
        
        return b
    }
    
    /// Destroy a rigid body given a definition. No reference to the definition
    /// is retained. This function is locked during callbacks.
    /// @warning This automatically deletes all associated shapes and joints.
    /// @warning This function is locked during callbacks.
    open func destroyBody(_ b: b2Body) {
        assert(m_bodyCount > 0)
        assert(isLocked == false)
        if isLocked {
            return
        }
        
        // Delete the attached joints.
        var je = b.m_jointList
        while je != nil {
            let je0 = je!
            je = je!.next
            
            if m_destructionListener != nil {
                m_destructionListener!.sayGoodbye(je0.joint)
            }
            
            destroyJoint(je0.joint)
            
            b.m_jointList = je
        }
        b.m_jointList = nil
        
        // Delete the attached contacts.
        var ce = b.m_contactList
        while ce != nil {
            let ce0 = ce!
            ce = ce!.next
            m_contactManager.destroy(ce0.contact)
        }
        b.m_contactList = nil
        
        // Delete the attached fixtures. This destroys broad-phase proxies.
        var f = b.m_fixtureList
        while f != nil {
            let f0 = f!
            f = f!.m_next
            
            if m_destructionListener != nil {
                m_destructionListener!.sayGoodbye(f0)
            }
            
            f0.destroyProxies(m_contactManager.m_broadPhase)
            f0.destroy()
            
            b.m_fixtureList = f
            b.m_fixtureCount -= 1
        }
        b.m_fixtureList = nil
        b.m_fixtureCount = 0
        
        // Remove world body list.
        if b.m_prev != nil {
            b.m_prev!.m_next = b.m_next
        }
        
        if b.m_next != nil {
            b.m_next!.m_prev = b.m_prev
        }
        
        if b === m_bodyList {
            m_bodyList = b.m_next
        }
        
        m_bodyCount -= 1
    }
    
    /// Create a joint to constrain bodies together. No reference to the definition
    /// is retained. This may cause the connected bodies to cease colliding.
    /// @warning This function is locked during callbacks.
    @discardableResult open func createJoint(_ def: b2JointDef) -> b2Joint {
        assert(isLocked == false)
        if isLocked {
            fatalError("world is locked")
        }
        
        let j = b2Joint.create(def)
        
        // Connect to the world list.
        j.m_prev = nil
        j.m_next = m_jointList
        if m_jointList != nil {
            m_jointList!.m_prev = j
        }
        m_jointList = j
        m_jointCount += 1
        
        // Connect to the bodies' doubly linked lists.
        j.m_edgeA.joint = j
        j.m_edgeA.other = j.m_bodyB
        j.m_edgeA.prev = nil
        j.m_edgeA.next = j.m_bodyA.m_jointList
        if j.m_bodyA.m_jointList != nil {
            j.m_bodyA.m_jointList!.prev = j.m_edgeA
        }
        j.m_bodyA.m_jointList = j.m_edgeA
        
        j.m_edgeB.joint = j
        j.m_edgeB.other = j.m_bodyA
        j.m_edgeB.prev = nil
        j.m_edgeB.next = j.m_bodyB.m_jointList
        if j.m_bodyB.m_jointList != nil {
            j.m_bodyB.m_jointList!.prev = j.m_edgeB
        }
        j.m_bodyB.m_jointList = j.m_edgeB
        
        let bodyA = def.bodyA
        let bodyB = def.bodyB
        
        // If the joint prevents collisions, then flag any contacts for filtering.
        if def.collideConnected == false {
            var edge = bodyB?.getContactList()
            while edge != nil {
                if edge!.other === bodyA {
                    // Flag the contact for filtering at the next time step (where either
                    // body is awake).
                    edge!.contact.flagForFiltering()
                }
                
                edge = edge!.next
            }
        }
        
        // Note: creating a joint doesn't wake the bodies.
        return j
    }
    
    @discardableResult open func createJoint(_ def: b2DistanceJointDef) -> b2DistanceJoint {
        return createJoint(def as b2JointDef) as! b2DistanceJoint
    }
    @discardableResult open func createJoint(_ def: b2MouseJointDef) -> b2MouseJoint {
        return createJoint(def as b2JointDef) as! b2MouseJoint
    }
    @discardableResult open func createJoint(_ def: b2PrismaticJointDef) -> b2PrismaticJoint {
        return createJoint(def as b2JointDef) as! b2PrismaticJoint
    }
    @discardableResult open func createJoint(_ def: b2RevoluteJointDef) -> b2RevoluteJoint {
        return createJoint(def as b2JointDef) as! b2RevoluteJoint
    }
    @discardableResult open func createJoint(_ def: b2PulleyJointDef) -> b2PulleyJoint {
        return createJoint(def as b2JointDef) as! b2PulleyJoint
    }
    @discardableResult open func createJoint(_ def: b2GearJointDef) -> b2GearJoint {
        return createJoint(def as b2JointDef) as! b2GearJoint
    }
    @discardableResult open func createJoint(_ def: b2WheelJointDef) -> b2WheelJoint {
        return createJoint(def as b2JointDef) as! b2WheelJoint
    }
    @discardableResult open func createJoint(_ def: b2WeldJointDef) -> b2WeldJoint {
        return createJoint(def as b2JointDef) as! b2WeldJoint
    }
    @discardableResult open func createJoint(_ def: b2FrictionJointDef) -> b2FrictionJoint {
        return createJoint(def as b2JointDef) as! b2FrictionJoint
    }
    @discardableResult open func createJoint(_ def: b2RopeJointDef) -> b2RopeJoint {
        return createJoint(def as b2JointDef) as! b2RopeJoint
    }
    @discardableResult open func createJoint(_ def: b2MotorJointDef) -> b2MotorJoint {
        return createJoint(def as b2JointDef) as! b2MotorJoint
    }
    
    /// Destroy a joint. This may cause the connected bodies to begin colliding.
    /// @warning This function is locked during callbacks.
    open func destroyJoint(_ j: b2Joint) {
        assert(isLocked == false)
        if isLocked {
            return
        }
        
        let collideConnected = j.m_collideConnected
        
        // Remove from the doubly linked list.
        if j.m_prev != nil {
            j.m_prev!.m_next = j.m_next
        }
        
        if j.m_next != nil {
            j.m_next!.m_prev = j.m_prev
        }
        
        if j === m_jointList {
            m_jointList = j.m_next
        }
        
        // Disconnect from island graph.
        let bodyA = j.m_bodyA
        let bodyB = j.m_bodyB
        
        // Wake up connected bodies.
        bodyA.setAwake(true)
        bodyB.setAwake(true)
        
        // Remove from body 1.
        if j.m_edgeA.prev != nil {
            j.m_edgeA.prev!.next = j.m_edgeA.next
        }
        
        if j.m_edgeA.next != nil {
            j.m_edgeA.next!.prev = j.m_edgeA.prev
        }
        
        if j.m_edgeA === bodyA.m_jointList {
            bodyA.m_jointList = j.m_edgeA.next
        }
        
        j.m_edgeA.prev = nil
        j.m_edgeA.next = nil
        
        // Remove from body 2
        if j.m_edgeB.prev != nil {
            j.m_edgeB.prev!.next = j.m_edgeB.next
        }
        
        if j.m_edgeB.next != nil {
            j.m_edgeB.next!.prev = j.m_edgeB.prev
        }
        
        if j.m_edgeB === bodyB.m_jointList {
            bodyB.m_jointList = j.m_edgeB.next
        }
        
        j.m_edgeB.prev = nil
        j.m_edgeB.next = nil
        
        b2Joint.destroy(j)
        
        assert(m_jointCount > 0)
        m_jointCount -= 1
        
        // If the joint prevents collisions, then flag any contacts for filtering.
        if collideConnected == false {
            var edge = bodyB.getContactList()
            while edge != nil {
                if edge!.other === bodyA {
                    // Flag the contact for filtering at the next time step (where either
                    // body is awake).
                    edge!.contact.flagForFiltering()
                }
                
                edge = edge!.next
            }
        }
    }
    
    /**
     Take a time step. This performs collision detection, integration,
     and constraint solution.
     
     - parameter timeStep: the amount of time to simulate, this should not vary.
     - parameter velocityIterations: for the velocity constraint solver.
     - parameter positionIterations: for the position constraint solver.
     */
    open func step(timeStep dt: b2Float, velocityIterations: Int, positionIterations: Int) {
        let stepTimer = b2Timer()
        
        // If new fixtures were added, we need to find the new contacts.
        if (m_flags & Flags.newFixture) != 0 {
            m_contactManager.findNewContacts()
            m_flags &= ~Flags.newFixture
        }
        
        m_flags |= Flags.locked
        
        var step = b2TimeStep()
        step.dt = dt
        step.velocityIterations	= velocityIterations
        step.positionIterations = positionIterations
        if dt > 0.0 {
            step.inv_dt = 1.0 / dt
        }
        else {
            step.inv_dt = 0.0
        }
        
        step.dtRatio = m_inv_dt0 * dt
        
        step.warmStarting = m_warmStarting
        
        // Update contacts. This is where some contacts are destroyed.
        //{
        let timer = b2Timer()
        m_contactManager.collide()
        m_profile.collide = timer.milliseconds
        //}
        
        // Integrate velocities, solve velocity constraints, and integrate positions.
        if m_stepComplete && step.dt > 0.0 {
            let timer = b2Timer()
            solve(step)
            m_profile.solve = timer.milliseconds
        }
        
        // Handle TOI events.
        if m_continuousPhysics && step.dt > 0.0 {
            let timer = b2Timer()
            solveTOI(step)
            m_profile.solveTOI = timer.milliseconds
        }
        
        if step.dt > 0.0 {
            m_inv_dt0 = step.inv_dt
        }
        
        if (m_flags & Flags.clearForces) != 0 {
            clearForces()
        }
        
        m_flags &= ~Flags.locked
        
        m_profile.step = stepTimer.milliseconds
    }
    
    /// Manually clear the force buffer on all bodies. By default, forces are cleared automatically
    /// after each call to Step. The default behavior is modified by calling SetAutoClearForces.
    /// The purpose of this function is to support sub-stepping. Sub-stepping is often used to maintain
    /// a fixed sized time step under a variable frame-rate.
    /// When you perform sub-stepping you will disable auto clearing of forces and instead call
    /// ClearForces after all sub-steps are complete in one pass of your game loop.
    /// @see SetAutoClearForces
    open func clearForces() {
        var body = m_bodyList
        while body != nil
        {
            body!.m_force.setZero()
            body!.m_torque = 0.0
            body = body!.getNext()
        }
    }
    
    /// Call this to draw shapes and other debug draw data. This is intentionally non-const.
    open func drawDebugData() {
        if m_debugDraw == nil {
            return
        }
        
        let flags = m_debugDraw!.flags
        
        if (flags & b2DrawFlags.shapeBit) != 0 {
            var b = m_bodyList
            while b != nil
            {
                let xf = b!.transform
                var f = b!.getFixtureList()
                while f != nil {
                    if b!.isActive == false {
                        drawShape(f!, xf, b2Color(0.5, 0.5, 0.3))
                    }
                    else if b!.type == b2BodyType.staticBody {
                        drawShape(f!, xf, b2Color(0.5, 0.9, 0.5))
                    }
                    else if b!.type == b2BodyType.kinematicBody {
                        drawShape(f!, xf, b2Color(0.5, 0.5, 0.9))
                    }
                    else if b!.isAwake == false {
                        drawShape(f!, xf, b2Color(0.6, 0.6, 0.6))
                    }
                    else {
                        drawShape(f!, xf, b2Color(0.9, 0.7, 0.7))
                    }
                    f = f!.getNext()
                }
                b = b!.getNext()
            }
        }
        
        if (flags & b2DrawFlags.jointBit) != 0 {
            var j = m_jointList
            while j != nil {
                drawJoint(j!)
                j = j!.getNext()
            }
        }
        
        if (flags & b2DrawFlags.pairBit) != 0 {
            //      let color = b2Color(0.3, 0.9, 0.9)
            var c = m_contactManager.m_contactList
            while c != nil {
                //let fixtureA = c!.fixtureA
                //let fixtureB = c!.fixtureB
                
                //let cA = fixtureA.GetAABB().GetCenter()
                //let cB = fixtureB.GetAABB().GetCenter()
                
                //m_debugDraw.drawSegment(cA, cB, color)
                c = c!.getNext()
            }
        }
        
        if (flags & b2DrawFlags.aabbBit) != 0 {
            let color = b2Color(0.9, 0.3, 0.9)
            let bp = m_contactManager.m_broadPhase
            var b = m_bodyList
            while b != nil {
                if b!.isActive == false {
                    continue
                }
                var f = b!.getFixtureList()
                while f != nil {
                    for i in 0 ..< f!.m_proxyCount {
                        let proxy = f!.m_proxies[i]
                        let aabb = bp.getFatAABB(proxyId: proxy.proxyId)
                        var vs = [b2Vec2](repeating: b2Vec2(), count: 4)
                        vs[0].set(aabb.lowerBound.x, aabb.lowerBound.y)
                        vs[1].set(aabb.upperBound.x, aabb.lowerBound.y)
                        vs[2].set(aabb.upperBound.x, aabb.upperBound.y)
                        vs[3].set(aabb.lowerBound.x, aabb.upperBound.y)
                        
                        m_debugDraw!.drawPolygon(vs, color)
                    }
                    f = f!.getNext()
                }
                b = b!.getNext()
            }
        }
        
        if (flags & b2DrawFlags.centerOfMassBit) != 0 {
            var b = m_bodyList
            while b != nil {
                var xf = b!.transform
                xf.p = b!.worldCenter
                m_debugDraw!.drawTransform(xf)
                b = b!.getNext()
            }
        }
    }
    
    /**
     Query the world for all fixtures that potentially overlap the
     provided AABB.
     
     - parameter callback: a user implemented callback class.
     - parameter aabb: the query box.
     */
    open func queryAABB(callback: b2QueryCallback, aabb: b2AABB) {
        var wrapper = b2WorldQueryWrapper()
        wrapper.broadPhase = m_contactManager.m_broadPhase
        wrapper.callback = callback
        m_contactManager.m_broadPhase.query(callback: wrapper, aabb: aabb)
    }
    
    /**
     Query the world for all fixtures that potentially overlap the
     provided AABB.
     
     - parameter aabb: the query box.
     - parameter callback: a user implemented callback closure.
     */
    open func queryAABB(_ aabb: b2AABB, callback: @escaping b2QueryCallbackFunction) {
        queryAABB(callback: b2QueryCallbackProxy(callback: callback), aabb: aabb)
    }
    
    /**
     Ray-cast the world for all fixtures in the path of the ray. Your callback
     controls whether you get the closest point, any point, or n-points.
     The ray-cast ignores shapes that contain the starting point.
     
     - parameter callback: a user implemented callback class.
     - parameter point1: the ray starting point
     - parameter point2: the ray ending point
     */
    open func rayCast(callback: b2RayCastCallback, point1: b2Vec2, point2: b2Vec2) {
        var wrapper = b2WorldRayCastWrapper()
        wrapper.broadPhase = m_contactManager.m_broadPhase
        wrapper.callback = callback
        var input = b2RayCastInput()
        input.maxFraction = 1.0
        input.p1 = point1
        input.p2 = point2
        m_contactManager.m_broadPhase.rayCast(callback: wrapper, input: input)
    }
    
    /**
     Ray-cast the world for all fixtures in the path of the ray. Your callback
     controls whether you get the closest point, any point, or n-points.
     The ray-cast ignores shapes that contain the starting point.
     
     - parameter point1: the ray starting point
     - parameter point2: the ray ending point
     - parameter callback: a user implemented callback closure.
     */
    open func rayCast(_ point1: b2Vec2, point2: b2Vec2, callback: @escaping b2RayCastCallbackFunction) {
        rayCast(callback: b2RayCastCallbackProxy(callback: callback), point1: point1, point2: point2)
    }
    
    /// Get the world body list. With the returned body, use b2Body::GetNext to get
    /// the next body in the world list. A NULL body indicates the end of the list.
    /// @return the head of the world body list.
    open func getBodyList() -> b2Body? {
        return m_bodyList
    }
    
    /// Get the world joint list. With the returned joint, use b2Joint::GetNext to get
    /// the next joint in the world list. A NULL joint indicates the end of the list.
    /// @return the head of the world joint list.
    open func getJointList() -> b2Joint? {
        return m_jointList
    }
    
    /// Get the world contact list. With the returned contact, use b2Contact::GetNext to get
    /// the next contact in the world list. A NULL contact indicates the end of the list.
    /// @return the head of the world contact list.
    /// @warning contacts are created and destroyed in the middle of a time step.
    /// Use b2ContactListener to avoid missing contacts.
    open func getContactList() -> b2Contact? {
        return m_contactManager.m_contactList
    }
    
    /// Enable/disable sleep.
    open func setAllowSleeping(_ flag: Bool) {
        if flag == m_allowSleep {
            return
        }
        
        m_allowSleep = flag
        if m_allowSleep == false {
            var b = m_bodyList
            while b != nil {
                b!.setAwake(true)
                b = b!.m_next
            }
        }
    }
    open var allowSleeping: Bool {
        get {
            return m_allowSleep
        }
        set {
            setAllowSleeping(newValue)
        }
    }
    
    /// Enable/disable warm starting. For testing.
    open func setWarmStarting(_ flag: Bool) { m_warmStarting = flag }
    open var warmStarting: Bool {
        get {
            return m_warmStarting
        }
        set {
            setWarmStarting(newValue)
        }
    }
    
    /// Enable/disable continuous physics. For testing.
    open func setContinuousPhysics(_ flag: Bool) { m_continuousPhysics = flag }
    open var continuousPhysics: Bool {
        get {
            return m_continuousPhysics
        }
        set {
            setContinuousPhysics(newValue)
        }
    }
    
    /// Enable/disable single stepped continuous physics. For testing.
    open func setSubStepping(_ flag: Bool) { m_subStepping = flag }
    open var subStepping: Bool {
        get {
            return m_subStepping
        }
        set {
            setSubStepping(newValue)
        }
    }
    
    /// Get the number of broad-phase proxies.
    open var proxyCount: Int {
        return m_contactManager.m_broadPhase.getProxyCount()
    }
    
    /// Get the number of bodies.
    open var bodyCount: Int {
        return m_bodyCount
    }
    
    /// Get the number of joints.
    open var jointCount: Int {
        return m_jointCount
    }
    
    /// Get the number of contacts (each may have 0 or more contact points).
    open var contactCount: Int {
        return m_contactManager.m_contactCount
    }
    
    /// Get the height of the dynamic tree.
    open var treeHeight: Int {
        return m_contactManager.m_broadPhase.getTreeHeight()
    }
    
    /// Get the balance of the dynamic tree.
    open var treeBalance: Int {
        return m_contactManager.m_broadPhase.getTreeBalance()
    }
    
    /// Get the quality metric of the dynamic tree. The smaller the better.
    /// The minimum is 1.
    open var treeQuality: b2Float {
        return m_contactManager.m_broadPhase.getTreeQuality()
    }
    
    /// Change the global gravity vector.
    open func setGravity(_ gravity: b2Vec2) {
        m_gravity = gravity
    }
    
    /// Get the global gravity vector.
    open var gravity: b2Vec2 {
        get {
            return m_gravity
        }
        set {
            setGravity(newValue)
        }
    }
    
    /// Is the world locked (in the middle of a time step).
    open var isLocked: Bool {
        return (m_flags & Flags.locked) == Flags.locked
    }
    
    /// Set flag to control automatic clearing of forces after each time step.
    open func setAutoClearForces(_ flag: Bool) {
        if flag {
            m_flags |= Flags.clearForces
        }
        else {
            m_flags &= ~Flags.clearForces
        }
    }
    
    /// Get the flag that controls automatic clearing of forces after each time step.
    open var autoClearForces: Bool {
        return (m_flags & Flags.clearForces) == Flags.clearForces
    }
    
    /// Shift the world origin. Useful for large worlds.
    /// The body shift formula is: position -= newOrigin
    /// @param newOrigin the new origin with respect to the old origin
    open func shiftOrigin(_ newOrigin: b2Vec2) {
        assert((m_flags & Flags.locked) == 0)
        if (m_flags & Flags.locked) == Flags.locked {
            return
        }
        var b = m_bodyList
        while b != nil {
            b!.m_xf.p -= newOrigin
            b!.m_sweep.c0 -= newOrigin
            b!.m_sweep.c -= newOrigin
            b = b!.m_next
        }
        
        var j = m_jointList
        while j != nil {
            j!.shiftOrigin(newOrigin)
            j = j!.m_next
        }
        
        m_contactManager.m_broadPhase.shiftOrigin(newOrigin)
    }
    
    /// Get the contact manager for testing.
    open var contactManager: b2ContactManager {
        return m_contactManager
    }
    
    /// Get the current profile.
    open var profile: b2Profile {
        return m_profile
    }
    /// Dump the world into the log file.
    /// @warning this should be called outside of a time step.
    open func dump() {
        if (m_flags & Flags.locked) == Flags.locked {
            return
        }
        
        print("b2Vec2 g(\(m_gravity.x), \(m_gravity.y));")
        print("m_world->setGravity(g);")
        
        print("b2Body** bodies = (b2Body**)b2Alloc(\(m_bodyCount) * sizeof(b2Body*));")
        print("b2Joint** joints = (b2Joint**)b2Alloc(\(m_jointCount) * sizeof(b2Joint*));")
        var i = 0
        var b = m_bodyList
        while b != nil {
            b!.m_islandIndex = i
            b!.dump()
            i += 1
            b = b!.m_next
        }
        
        i = 0
        
        var j = m_jointList;
        while j != nil {
            j!.m_index = i
            i += 1
            j = j!.m_next
        }
        
        // First pass on joints, skip gear joints.
        j = m_jointList
        while j != nil {
            if j!.m_type == b2JointType.gearJoint {
                j = j!.m_next
                continue
            }
            
            print("{")
            j!.dump()
            print("}")
            j = j!.m_next
        }
        
        // Second pass on joints, only gear joints.
        j = m_jointList
        while j != nil {
            if j!.m_type != b2JointType.gearJoint {
                j = j!.m_next
                continue
            }
            
            print("{")
            j!.dump()
            print("}")
        }
        
        print("b2Free(joints);")
        print("b2Free(bodies);")
        print("joints = NULL;")
        print("bodies = NULL;")
        j = j!.m_next
    }
    
    // MARK: - private methods
    
    struct Flags {
        static let newFixture: UInt32	= 0x0001
        static let locked: UInt32		= 0x0002
        static let clearForces: UInt32	= 0x0004
    }
    
    // Find islands, integrate and solve constraints, solve position constraints
    func solve(_ step: b2TimeStep) {
        m_profile.solveInit = 0.0
        m_profile.solveVelocity = 0.0
        m_profile.solvePosition = 0.0
        
        // Size the island for the worst case.
        if m_island == nil {
            m_island = b2Island(m_bodyCount,
                                m_contactManager.m_contactCount,
                                m_jointCount,
                                m_contactManager.m_contactListener)
        }
        else {
            m_island.reset(m_bodyCount,
                           m_contactManager.m_contactCount,
                           m_jointCount,
                           m_contactManager.m_contactListener)
        }
        let island = m_island! // never nil
        
        // Clear all the island flags.
        var b = m_bodyList
        while b != nil {
            b!.m_flags &= ~b2Body.Flags.islandFlag
            b = b!.m_next
        }
        var c = m_contactManager.m_contactList
        while c != nil {
            c!.m_flags &= ~b2Contact.Flags.islandFlag
            c = c!.m_next
        }
        var j = m_jointList
        while j != nil {
            j!.m_islandFlag = false
            j = j!.m_next
        }
        
        // Build and simulate all awake islands.
        let stackSize = m_bodyCount
        var stack = [b2Body]()
        stack.reserveCapacity(stackSize)
        var seed = m_bodyList
        while seed != nil {
            if (seed!.m_flags & b2Body.Flags.islandFlag) != 0 {
                seed = seed!.m_next
                continue
            }
            
            if seed!.isAwake == false || seed!.isActive == false {
                seed = seed!.m_next
                continue
            }
            
            // The seed can be dynamic or kinematic.
            if seed!.type == b2BodyType.staticBody {
                seed = seed!.m_next
                continue
            }
            
            // Reset island and stack.
            island.clear()
            //var stackCount: Int = 0
            stack.append(seed!)
            seed!.m_flags |= b2Body.Flags.islandFlag
            // Perform a depth first search (DFS) on the constraint graph.
            while stack.count > 0 {
                // Grab the next body off the stack and add it to the island.
                let b = stack.removeLast()
                assert(b.isActive == true)
                island.add(b)
                
                // Make sure the body is awake.
                b.setAwake(true)
                
                // To keep islands as small as possible, we don't
                // propagate islands across static bodies.
                if b.type == b2BodyType.staticBody {
                    continue
                }
                
                // Search all contacts connected to this body.
                var ce = b.m_contactList
                while ce != nil {
                    let contact = ce!.contact
                    
                    // Has this contact already been added to an island?
                    if (contact.m_flags & b2Contact.Flags.islandFlag) != 0 {
                        ce = ce!.next
                        continue
                    }
                    
                    // Is this contact solid and touching?
                    if contact.isEnabled == false || contact.isTouching == false {
                        ce = ce!.next
                        continue
                    }
                    
                    // Skip sensors.
                    let sensorA = contact.m_fixtureA.m_isSensor
                    let sensorB = contact.m_fixtureB.m_isSensor
                    if sensorA || sensorB {
                        ce = ce!.next
                        continue
                    }
                    
                    island.add(contact)
                    contact.m_flags |= b2Contact.Flags.islandFlag
                    
                    let other = ce!.other
                    
                    // Was the other body already added to this island?
                    if ((other?.m_flags)! & b2Body.Flags.islandFlag) != 0 {
                        ce = ce!.next
                        continue
                    }
                    
                    assert(stack.count < stackSize)
                    stack.append(other!)
                    other?.m_flags |= b2Body.Flags.islandFlag
                    ce = ce!.next
                }
                
                // Search all joints connect to this body.
                var je = b.m_jointList
                while je != nil {
                    if je!.joint.m_islandFlag == true {
                        je = je!.next
                        continue
                    }
                    
                    let other: b2Body = je!.other
                    
                    // Don't simulate joints connected to inactive bodies.
                    if other.isActive == false {
                        je = je!.next
                        continue
                    }
                    
                    island.add(je!.joint)
                    je!.joint.m_islandFlag = true
                    
                    if (other.m_flags & b2Body.Flags.islandFlag) != 0 {
                        je = je!.next
                        continue
                    }
                    
                    assert(stack.count < stackSize)
                    stack.append(other)
                    other.m_flags |= b2Body.Flags.islandFlag
                }
            }
            
            var profile = b2Profile()
            island.solve(&profile, step, m_gravity, m_allowSleep)
            m_profile.solveInit += profile.solveInit
            m_profile.solveVelocity += profile.solveVelocity
            m_profile.solvePosition += profile.solvePosition
            
            // Post solve cleanup.
            for i in 0 ..< island.m_bodyCount {
                // Allow static bodies to participate in other islands.
                let b = island.m_bodies[i]
                if b.type == b2BodyType.staticBody {
                    b.m_flags &= ~b2Body.Flags.islandFlag
                }
            }
            seed = seed!.m_next
        }
        
        //m_stackAllocator.Free(stack)
        stack.removeAll()
        
        let timer = b2Timer()
        b2Locally {
            // Synchronize fixtures, check for out of range bodies.
            var b = self.m_bodyList;
            while b != nil {
                // If a body was not in an island then it did not move.
                if (b!.m_flags & b2Body.Flags.islandFlag) == 0 {
                    b = b!.getNext()
                    continue
                }
                
                if b!.type == b2BodyType.staticBody {
                    b = b!.getNext()
                    continue
                }
                
                // Update fixtures (for broad-phase).
                b!.synchronizeFixtures()
                b = b!.getNext()
            }
        }
        
        // Look for new contacts.
        m_contactManager.findNewContacts()
        m_profile.broadphase = timer.milliseconds
        
    }
    
    // Find TOI contacts and solve them.
    func solveTOI(_ step: b2TimeStep) {
        if m_TOIIsland == nil {
            m_TOIIsland = b2Island(2 * b2_maxTOIContacts, b2_maxTOIContacts, 0, m_contactManager.m_contactListener)
        }
        else {
            m_TOIIsland.reset(2 * b2_maxTOIContacts, b2_maxTOIContacts, 0, m_contactManager.m_contactListener)
        }
        let island = m_TOIIsland! // never nil
        
        if m_stepComplete {
            var b = m_bodyList
            while b != nil {
                b!.m_flags &= ~b2Body.Flags.islandFlag
                b!.m_sweep.alpha0 = 0.0
                b = b!.m_next
            }
            var c = m_contactManager.m_contactList
            while c != nil {
                // Invalidate TOI
                c!.m_flags &= ~(b2Contact.Flags.toiFlag | b2Contact.Flags.islandFlag)
                c!.m_toiCount = 0
                c!.m_toi = 1.0
                c = c!.m_next
            }
        }
        
        // Find TOI events and solve them.
        while true {
            // Find the first TOI.
            var minContact: b2Contact? = nil
            var minAlpha: b2Float = 1.0
            var c = m_contactManager.m_contactList
            while c != nil {
                //for (var c = m_contactManager.m_contactList; c != nil; c = c!.m_next) {
                // Is this contact disabled?
                if c!.isEnabled == false {
                    c = c!.m_next
                    continue
                }
                
                // Prevent excessive sub-stepping.
                if c!.m_toiCount > b2_maxSubSteps {
                    c = c!.m_next
                    continue
                }
                
                var alpha: b2Float = 1.0
                if (c!.m_flags & b2Contact.Flags.toiFlag) != 0 {
                    // This contact has a valid cached TOI.
                    alpha = c!.m_toi
                }
                else {
                    let fA = c!.fixtureA
                    let fB = c!.fixtureB
                    
                    // Is there a sensor?
                    if fA.isSensor || fB.isSensor {
                        c = c!.m_next
                        continue
                    }
                    
                    let bA = fA.body
                    let bB = fB.body
                    
                    let typeA = bA.m_type
                    let typeB = bB.m_type
                    assert(typeA == b2BodyType.dynamicBody || typeB == b2BodyType.dynamicBody)
                    
                    let activeA = bA.isAwake && typeA != b2BodyType.staticBody
                    let activeB = bB.isAwake && typeB != b2BodyType.staticBody
                    
                    // Is at least one body active (awake and dynamic or kinematic)?
                    if activeA == false && activeB == false {
                        c = c!.m_next
                        continue
                    }
                    
                    let collideA = bA.isBullet || typeA != b2BodyType.dynamicBody
                    let collideB = bB.isBullet || typeB != b2BodyType.dynamicBody
                    
                    // Are these two non-bullet dynamic bodies?
                    if collideA == false && collideB == false {
                        c = c!.m_next
                        continue
                    }
                    
                    // Compute the TOI for this contact.
                    // Put the sweeps onto the same time interval.
                    var alpha0 = bA.m_sweep.alpha0
                    
                    if bA.m_sweep.alpha0 < bB.m_sweep.alpha0 {
                        alpha0 = bB.m_sweep.alpha0
                        bA.m_sweep.advance(alpha: alpha0)
                    }
                    else if bB.m_sweep.alpha0 < bA.m_sweep.alpha0 {
                        alpha0 = bA.m_sweep.alpha0
                        bB.m_sweep.advance(alpha: alpha0)
                    }
                    
                    assert(alpha0 < 1.0)
                    
                    let indexA = c!.childIndexA
                    let indexB = c!.childIndexB
                    
                    // Compute the time of impact in interval [0, minTOI]
                    var input = b2TOIInput()
                    input.proxyA.set(fA.shape, indexA)
                    input.proxyB.set(fB.shape, indexB)
                    input.sweepA = bA.m_sweep
                    input.sweepB = bB.m_sweep
                    input.tMax = 1.0
                    
                    var output = b2TOIOutput()
                    b2TimeOfImpact(&output, input: input)
                    
                    // Beta is the fraction of the remaining portion of the .
                    let beta = output.t
                    if output.state == b2TOIOutput.State.touching {
                        alpha = min(alpha0 + (1.0 - alpha0) * beta, 1.0)
                    }
                    else {
                        alpha = 1.0
                    }
                    
                    c!.m_toi = alpha
                    c!.m_flags |= b2Contact.Flags.toiFlag
                }
                
                if alpha < minAlpha {
                    // This is the minimum TOI found so far.
                    minContact = c
                    minAlpha = alpha
                }
                c = c!.m_next
            }
            
            if minContact == nil || 1.0 - 10.0 * b2_epsilon < minAlpha {
                // No more TOI events. Done!
                m_stepComplete = true
                break
            }
            
            // Advance the bodies to the TOI.
            let fA = minContact!.fixtureA
            let fB = minContact!.fixtureB
            let bA = fA.body
            let bB = fB.body
            
            let backup1 = bA.m_sweep
            let backup2 = bB.m_sweep
            
            bA.advance(minAlpha)
            bB.advance(minAlpha)
            
            // The TOI contact likely has some new contact points.
            minContact!.update(m_contactManager.m_contactListener)
            minContact!.m_flags &= ~b2Contact.Flags.toiFlag
            minContact!.m_toiCount += 1
            
            // Is the contact solid?
            if minContact!.isEnabled == false || minContact!.isTouching == false {
                // Restore the sweeps.
                minContact!.setEnabled(false)
                bA.m_sweep = backup1
                bB.m_sweep = backup2
                bA.synchronizeTransform()
                bB.synchronizeTransform()
                continue
            }
            
            bA.setAwake(true)
            bB.setAwake(true)
            
            // Build the island
            island.clear()
            island.add(bA)
            island.add(bB)
            island.add(minContact!)
            
            bA.m_flags |= b2Body.Flags.islandFlag
            bB.m_flags |= b2Body.Flags.islandFlag
            minContact!.m_flags |= b2Contact.Flags.islandFlag
            
            // Get contacts on bodyA and bodyB.
            let bodies = [bA, bB]
            for i in 0 ..< 2 {
                let body = bodies[i]
                if body.m_type == b2BodyType.dynamicBody {
                    var ce = body.m_contactList
                    while ce != nil {
                        if island.m_bodyCount == island.m_bodyCapacity {
                            break
                        }
                        
                        if island.m_contactCount == island.m_contactCapacity {
                            break
                        }
                        
                        let contact = ce!.contact
                        
                        // Has this contact already been added to the island?
                        if (contact.m_flags & b2Contact.Flags.islandFlag) != 0 {
                            ce = ce!.next
                            continue
                        }
                        
                        // Only add static, kinematic, or bullet bodies.
                        let other = ce!.other!
                        if other.m_type == b2BodyType.dynamicBody &&
                            body.isBullet == false && other.isBullet == false {
                            ce = ce!.next
                            continue
                        }
                        
                        // Skip sensors.
                        let sensorA = contact.m_fixtureA.m_isSensor
                        let sensorB = contact.m_fixtureB.m_isSensor
                        if sensorA || sensorB {
                            ce = ce!.next
                            continue
                        }
                        
                        // Tentatively advance the body to the TOI.
                        let backup = other.m_sweep
                        if (other.m_flags & b2Body.Flags.islandFlag) == 0 {
                            other.advance(minAlpha)
                        }
                        
                        // Update the contact points
                        contact.update(m_contactManager.m_contactListener)
                        
                        // Was the contact disabled by the user?
                        if contact.isEnabled == false {
                            other.m_sweep = backup
                            other.synchronizeTransform()
                            ce = ce!.next
                            continue
                        }
                        
                        // Are there contact points?
                        if contact.isTouching == false {
                            other.m_sweep = backup
                            other.synchronizeTransform()
                            ce = ce!.next
                            continue
                        }
                        
                        // Add the contact to the island
                        contact.m_flags |= b2Contact.Flags.islandFlag
                        island.add(contact)
                        
                        // Has the other body already been added to the island?
                        if (other.m_flags & b2Body.Flags.islandFlag) != 0 {
                            ce = ce!.next
                            continue
                        }
                        
                        // Add the other body to the island.
                        other.m_flags |= b2Body.Flags.islandFlag
                        
                        if other.m_type != b2BodyType.staticBody {
                            other.setAwake(true)
                        }
                        
                        island.add(other)
                        ce = ce!.next
                    }
                }
            }
            
            var subStep = b2TimeStep()
            subStep.dt = (1.0 - minAlpha) * step.dt
            subStep.inv_dt = 1.0 / subStep.dt
            subStep.dtRatio = 1.0
            subStep.positionIterations = 20
            subStep.velocityIterations = step.velocityIterations
            subStep.warmStarting = false
            island.solveTOI(subStep, bA.m_islandIndex, bB.m_islandIndex)
            
            // Reset island flags and synchronize broad-phase proxies.
            for i in 0 ..< island.m_bodyCount {
                let body = island.m_bodies[i]
                body.m_flags &= ~b2Body.Flags.islandFlag
                
                if body.m_type != b2BodyType.dynamicBody {
                    continue
                }
                
                body.synchronizeFixtures()
                
                // Invalidate all contact TOIs on this displaced body.
                var ce = body.m_contactList
                while ce != nil {
                    ce!.contact.m_flags &= ~(b2Contact.Flags.toiFlag | b2Contact.Flags.islandFlag)
                    ce = ce!.next
                }
            }
            
            // Commit fixture proxy movements to the broad-phase so that new contacts are created.
            // Also, some contacts can be destroyed.
            m_contactManager.findNewContacts()
            
            if m_subStepping {
                m_stepComplete = false
                break
            }
        }
    }
    
    func drawJoint(_ joint: b2Joint) {
        let bodyA = joint.bodyA
        let bodyB = joint.bodyB
        let xf1 = bodyA.transform
        let xf2 = bodyB.transform
        let x1 = xf1.p
        let x2 = xf2.p
        let p1 = joint.anchorA
        let p2 = joint.anchorB
        
        let color = b2Color(0.5, 0.8, 0.8)
        
        switch joint.type {
        case .distanceJoint:
            m_debugDraw?.drawSegment(p1, p2, color)
            
        case .pulleyJoint:
            let pulley = joint as! b2PulleyJoint
            let s1 = pulley.groundAnchorA
            let s2 = pulley.groundAnchorB
            m_debugDraw?.drawSegment(s1, p1, color)
            m_debugDraw?.drawSegment(s2, p2, color)
            m_debugDraw?.drawSegment(s1, s2, color)
            
        case .mouseJoint:
            // don't draw this
            break
            
        default:
            m_debugDraw?.drawSegment(x1, p1, color)
            m_debugDraw?.drawSegment(p1, p2, color)
            m_debugDraw?.drawSegment(x2, p2, color)
        }
    }
    
    func drawShape(_ fixture: b2Fixture, _ xf: b2Transform, _ color: b2Color) {
        switch fixture.type {
        case .circle:
            let circle = fixture.shape as! b2CircleShape
            
            let center = b2Mul(xf, circle.m_p)
            let radius = circle.m_radius
            let axis = b2Mul(xf.q, b2Vec2(1.0, 0.0))
            
            m_debugDraw?.drawSolidCircle(center, radius, axis, color)
            
        case .edge:
            let edge = fixture.shape as! b2EdgeShape
            let v1 = b2Mul(xf, edge.m_vertex1)
            let v2 = b2Mul(xf, edge.m_vertex2)
            m_debugDraw?.drawSegment(v1, v2, color)
            
        case .chain:
            let chain = fixture.shape as! b2ChainShape
            let count = chain.m_count
            let vertices = chain.m_vertices
            
            var v1 = b2Mul(xf, vertices[0])
            for i in 1 ..< count {
                let v2 = b2Mul(xf, vertices[i])
                m_debugDraw?.drawSegment(v1, v2, color)
                m_debugDraw?.drawCircle(v1, 0.05, color)
                v1 = v2
            }
            
        case .polygon:
            let poly = fixture.shape as! b2PolygonShape
            let vertexCount = poly.m_count
            assert(vertexCount <= b2_maxPolygonVertices)
            var vertices = [b2Vec2]()
            vertices.reserveCapacity(vertexCount)
            for i in 0 ..< vertexCount {
                vertices.append(b2Mul(xf, poly.m_vertices[i]))
            }
            
            m_debugDraw?.drawSolidPolygon(vertices, color)
            
        default:
            break
        }
    }
    
    // MARK: - private variables
    var m_island: b2Island! = nil
    var m_TOIIsland: b2Island! = nil
    
    var m_flags = Flags.clearForces
    
    var m_contactManager = b2ContactManager()
    
    var m_bodyList: b2Body? = nil   // ** owner **
    var m_jointList: b2Joint? = nil // ** owner **
    
    var m_bodyCount = 0
    var m_jointCount = 0
    
    var m_gravity: b2Vec2
    var m_allowSleep = true
    
    var m_destructionListener: b2DestructionListener? = nil
    var m_debugDraw: b2Draw? = nil
    
    // This is used to compute the time step ratio to
    // support a variable time step.
    var m_inv_dt0: b2Float = 0.0
    
    // These are for debugging the solver.
    var m_warmStarting = true
    var m_continuousPhysics = true
    var m_subStepping = false
    
    var m_stepComplete = true
    
    var m_profile = b2Profile()
}

struct b2WorldQueryWrapper : b2QueryWrapper {
    func queryCallback(_ proxyId: Int) -> Bool {
        let proxy = broadPhase.getUserData(proxyId: proxyId)!
        return callback.reportFixture(proxy.fixture)
    }
    
    var broadPhase: b2BroadPhase! = nil
    var callback: b2QueryCallback! = nil
}

struct b2WorldRayCastWrapper : b2RayCastWrapper {
    func rayCastCallback(_ input: b2RayCastInput, _ proxyId: Int) -> b2Float {
        let proxy = broadPhase.getUserData(proxyId: proxyId)!
        let fixture = proxy.fixture
        let index = proxy.childIndex
        var output = b2RayCastOutput()
        let hit = fixture.rayCast(&output, input: input, childIndex: index)
        
        if hit {
            let fraction = output.fraction
            let point = (1.0 - fraction) * input.p1 + fraction * input.p2
            return callback.reportFixture(fixture, point: point, normal: output.normal, fraction: fraction)
        }
        
        return input.maxFraction
    }
    
    var broadPhase: b2BroadPhase! = nil
    var callback: b2RayCastCallback! = nil
}
