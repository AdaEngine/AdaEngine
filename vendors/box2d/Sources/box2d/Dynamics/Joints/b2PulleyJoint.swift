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



let b2_minPulleyLength: b2Float = 2.0

/// Pulley joint definition. This requires two ground anchors,
/// two dynamic body anchor points, and a pulley ratio.
open class b2PulleyJointDef : b2JointDef {
    public override init() {
        groundAnchorA = b2Vec2(-1.0, 1.0)
        groundAnchorB = b2Vec2(1.0, 1.0)
        localAnchorA = b2Vec2(-1.0, 0.0)
        localAnchorB = b2Vec2(1.0, 0.0)
        lengthA = 0.0
        lengthB = 0.0
        ratio = 1.0
        super.init()
        type = b2JointType.pulleyJoint
        collideConnected = true
    }
    
    /// Initialize the bodies, anchors, lengths, max lengths, and ratio using the world anchors.
    public convenience init(bodyA: b2Body, bodyB: b2Body, groundAnchorA: b2Vec2, groundAnchorB: b2Vec2, anchorA: b2Vec2, anchorB: b2Vec2, ratio: b2Float) {
        self.init()
        initialize(bodyA: bodyA, bodyB: bodyB, groundAnchorA: groundAnchorA, groundAnchorB: groundAnchorB, anchorA: anchorA, anchorB: anchorB, ratio: ratio)
    }
    
    /// Initialize the bodies, anchors, lengths, max lengths, and ratio using the world anchors.
    open func initialize(bodyA: b2Body, bodyB: b2Body, groundAnchorA: b2Vec2, groundAnchorB: b2Vec2, anchorA: b2Vec2, anchorB: b2Vec2, ratio: b2Float) {
        self.bodyA = bodyA
        self.bodyB = bodyB
        self.groundAnchorA = groundAnchorA
        self.groundAnchorB = groundAnchorB
        self.localAnchorA = self.bodyA.getLocalPoint(anchorA)
        self.localAnchorB = self.bodyB.getLocalPoint(anchorB)
        let dA = anchorA - groundAnchorA
        self.lengthA = dA.length()
        let dB = anchorB - groundAnchorB
        self.lengthB = dB.length()
        self.ratio = ratio
        assert(ratio > b2_epsilon)
    }
    
    /// The first ground anchor in world coordinates. This point never moves.
    open var groundAnchorA: b2Vec2
    
    /// The second ground anchor in world coordinates. This point never moves.
    open var groundAnchorB: b2Vec2
    
    /// The local anchor point relative to bodyA's origin.
    open var localAnchorA: b2Vec2
    
    /// The local anchor point relative to bodyB's origin.
    open var localAnchorB: b2Vec2
    
    /// The a reference length for the segment attached to bodyA.
    open var lengthA: b2Float
    
    /// The a reference length for the segment attached to bodyB.
    open var lengthB: b2Float
    
    /// The pulley ratio, used to simulate a block-and-tackle.
    open var ratio: b2Float
}

// MARK: -
/// The pulley joint is connected to two bodies and two fixed ground points.
/// The pulley supports a ratio such that:
/// length1 + ratio * length2 <= constant
/// Yes, the force transmitted is scaled by the ratio.
/// Warning: the pulley joint can get a bit squirrelly by itself. They often
/// work better when combined with prismatic joints. You should also cover the
/// the anchor points with static shapes to prevent one side from going to
/// zero length.
open class b2PulleyJoint : b2Joint {
    open override var anchorA: b2Vec2 {
        return m_bodyA.getWorldPoint(m_localAnchorA)
    }
    open override var anchorB: b2Vec2 {
        return m_bodyB.getWorldPoint(m_localAnchorB)
    }
    
    open override func getReactionForce(inverseTimeStep inv_dt: b2Float) -> b2Vec2 {
        let P = m_impulse * m_uB
        return inv_dt * P
    }
    open override func getReactionTorque(inverseTimeStep inv_dt: b2Float) -> b2Float {
        return 0.0
    }
    
    /// Get the first ground anchor.
    open var groundAnchorA: b2Vec2 {
        return m_groundAnchorA
    }
    
    /// Get the second ground anchor.
    open var groundAnchorB: b2Vec2 {
        return m_groundAnchorB
    }
    
    /// Get the current length of the segment attached to bodyA.
    open var lengthA: b2Float {
        return m_lengthA
    }
    
    /// Get the current length of the segment attached to bodyB.
    open var lengthB: b2Float {
        return m_lengthB
    }
    
    /// Get the pulley ratio.
    open var ratio: b2Float {
        return m_ratio
    }
    
    /// Get the current length of the segment attached to bodyA.
    open var currentLengthA: b2Float {
        let p = m_bodyA.getWorldPoint(m_localAnchorA)
        let s = m_groundAnchorA
        let d = p - s
        return d.length()
    }
    
    /// Get the current length of the segment attached to bodyB.
    open var currentLengthB: b2Float {
        let p = m_bodyB.getWorldPoint(m_localAnchorB)
        let s = m_groundAnchorB
        let d = p - s
        return d.length()
    }
    
    /// Dump joint to dmLog
    open override func dump() {
        let indexA = m_bodyA.m_islandIndex
        let indexB = m_bodyB.m_islandIndex
        
        print("  b2PulleyJointDef jd;")
        print("  jd.bodyA = bodies[\(indexA)];")
        print("  jd.bodyB = bodies[\(indexB)];")
        print("  jd.collideConnected = bool(\(m_collideConnected));")
        print("  jd.groundAnchorA.set(\(m_groundAnchorA.x), \(m_groundAnchorA.y));")
        print("  jd.groundAnchorB.set(\(m_groundAnchorB.x), \(m_groundAnchorB.y));")
        print("  jd.localAnchorA.set(\(m_localAnchorA.x), \(m_localAnchorA.y));")
        print("  jd.localAnchorB.set(\(m_localAnchorB.x), \(m_localAnchorB.y));")
        print("  jd.lengthA = \(m_lengthA);")
        print("  jd.lengthB = \(m_lengthB);")
        print("  jd.ratio = \(m_ratio);")
        print("  joints[\(m_index)] = m_world->createJoint(&jd);")
    }
    
    /// Implement b2Joint::ShiftOrigin
    open override func shiftOrigin(_ newOrigin: b2Vec2) {
        m_groundAnchorA -= newOrigin
        m_groundAnchorB -= newOrigin
    }
    
    // MARK: private methods
    
    init(_ def: b2PulleyJointDef) {
        m_groundAnchorA = def.groundAnchorA
        m_groundAnchorB = def.groundAnchorB
        m_localAnchorA = def.localAnchorA
        m_localAnchorB = def.localAnchorB
        
        m_lengthA = def.lengthA
        m_lengthB = def.lengthB
        
        assert(def.ratio != 0.0)
        m_ratio = def.ratio
        
        m_constant = def.lengthA + m_ratio * def.lengthB
        
        m_impulse = 0.0
        super.init(def)
    }
    
    override func initVelocityConstraints(_ data: inout b2SolverData) {
        m_indexA = m_bodyA.m_islandIndex
        m_indexB = m_bodyB.m_islandIndex
        m_localCenterA = m_bodyA.m_sweep.localCenter
        m_localCenterB = m_bodyB.m_sweep.localCenter
        m_invMassA = m_bodyA.m_invMass
        m_invMassB = m_bodyB.m_invMass
        m_invIA = m_bodyA.m_invI
        m_invIB = m_bodyB.m_invI
        
        let cA = data.positions[m_indexA].c
        let aA = data.positions[m_indexA].a
        var vA = data.velocities[m_indexA].v
        var wA = data.velocities[m_indexA].w
        
        let cB = data.positions[m_indexB].c
        let aB = data.positions[m_indexB].a
        var vB = data.velocities[m_indexB].v
        var wB = data.velocities[m_indexB].w
        
        let qA = b2Rot(aA), qB = b2Rot(aB)
        
        m_rA = b2Mul(qA, m_localAnchorA - m_localCenterA)
        m_rB = b2Mul(qB, m_localAnchorB - m_localCenterB)
        
        // Get the pulley axes.
        m_uA = cA + m_rA - m_groundAnchorA
        m_uB = cB + m_rB - m_groundAnchorB
        
        let lengthA = m_uA.length()
        let lengthB = m_uB.length()
        
        if lengthA > 10.0 * b2_linearSlop {
            m_uA *= 1.0 / lengthA
        }
        else {
            m_uA.setZero()
        }
        
        if lengthB > 10.0 * b2_linearSlop {
            m_uB *= 1.0 / lengthB
        }
        else {
            m_uB.setZero()
        }
        
        // Compute effective mass.
        let ruA = b2Cross(m_rA, m_uA)
        let ruB = b2Cross(m_rB, m_uB)
        
        let mA = m_invMassA + m_invIA * ruA * ruA
        let mB = m_invMassB + m_invIB * ruB * ruB
        
        m_mass = mA + m_ratio * m_ratio * mB
        
        if m_mass > 0.0 {
            m_mass = 1.0 / m_mass
        }
        
        if data.step.warmStarting {
            // Scale impulses to support variable time steps.
            m_impulse *= data.step.dtRatio
            
            // Warm starting.
            let PA = -(m_impulse) * m_uA
            let PB = (-m_ratio * m_impulse) * m_uB
            
            vA += m_invMassA * PA
            wA += m_invIA * b2Cross(m_rA, PA)
            vB += m_invMassB * PB
            wB += m_invIB * b2Cross(m_rB, PB)
        }
        else {
            m_impulse = 0.0
        }
        
        data.velocities[m_indexA].v = vA
        data.velocities[m_indexA].w = wA
        data.velocities[m_indexB].v = vB
        data.velocities[m_indexB].w = wB
    }
    override func solveVelocityConstraints(_ data: inout b2SolverData) {
        var vA = data.velocities[m_indexA].v
        var wA = data.velocities[m_indexA].w
        var vB = data.velocities[m_indexB].v
        var wB = data.velocities[m_indexB].w
        
        let vpA = vA + b2Cross(wA, m_rA)
        let vpB = vB + b2Cross(wB, m_rB)
        
        let Cdot = -b2Dot(m_uA, vpA) - m_ratio * b2Dot(m_uB, vpB)
        let impulse = -m_mass * Cdot
        m_impulse += impulse
        
        let PA = -impulse * m_uA
        let PB = -m_ratio * impulse * m_uB
        vA += m_invMassA * PA
        wA += m_invIA * b2Cross(m_rA, PA)
        vB += m_invMassB * PB
        wB += m_invIB * b2Cross(m_rB, PB)
        
        data.velocities[m_indexA].v = vA
        data.velocities[m_indexA].w = wA
        data.velocities[m_indexB].v = vB
        data.velocities[m_indexB].w = wB
    }
    override func solvePositionConstraints(_ data: inout b2SolverData) -> Bool {
        var cA = data.positions[m_indexA].c
        var aA = data.positions[m_indexA].a
        var cB = data.positions[m_indexB].c
        var aB = data.positions[m_indexB].a
        
        let qA = b2Rot(aA), qB = b2Rot(aB)
        
        let rA = b2Mul(qA, m_localAnchorA - m_localCenterA)
        let rB = b2Mul(qB, m_localAnchorB - m_localCenterB)
        
        // Get the pulley axes.
        var uA = cA + rA - m_groundAnchorA
        var uB = cB + rB - m_groundAnchorB
        
        let lengthA = uA.length()
        let lengthB = uB.length()
        
        if lengthA > 10.0 * b2_linearSlop {
            uA *= 1.0 / lengthA
        }
        else {
            uA.setZero()
        }
        
        if lengthB > 10.0 * b2_linearSlop {
            uB *= 1.0 / lengthB
        }
        else {
            uB.setZero()
        }
        
        // Compute effective mass.
        let ruA = b2Cross(rA, uA)
        let ruB = b2Cross(rB, uB)
        
        let mA = m_invMassA + m_invIA * ruA * ruA
        let mB = m_invMassB + m_invIB * ruB * ruB
        
        var mass = mA + m_ratio * m_ratio * mB
        
        if mass > 0.0 {
            mass = 1.0 / mass
        }
        
        let C = m_constant - lengthA - m_ratio * lengthB
        let linearError = abs(C)
        
        let impulse = -mass * C
        
        let PA = -impulse * uA
        let PB = -m_ratio * impulse * uB
        
        cA += m_invMassA * PA
        aA += m_invIA * b2Cross(rA, PA)
        cB += m_invMassB * PB
        aB += m_invIB * b2Cross(rB, PB)
        
        data.positions[m_indexA].c = cA
        data.positions[m_indexA].a = aA
        data.positions[m_indexB].c = cB
        data.positions[m_indexB].a = aB
        
        return linearError < b2_linearSlop
    }
    
    // MARK: private variables
    
    var m_groundAnchorA: b2Vec2
    var m_groundAnchorB: b2Vec2
    var m_lengthA: b2Float
    var m_lengthB: b2Float
    
    // Solver shared
    var m_localAnchorA: b2Vec2
    var m_localAnchorB: b2Vec2
    var m_constant: b2Float
    var m_ratio: b2Float
    var m_impulse: b2Float
    
    // Solver temp
    var m_indexA: Int = 0
    var m_indexB: Int = 0
    var m_uA = b2Vec2()
    var m_uB = b2Vec2()
    var m_rA = b2Vec2()
    var m_rB = b2Vec2()
    var m_localCenterA = b2Vec2()
    var m_localCenterB = b2Vec2()
    var m_invMassA: b2Float = 0.0
    var m_invMassB: b2Float = 0.0
    var m_invIA: b2Float = 0.0
    var m_invIB: b2Float = 0.0
    var m_mass: b2Float = 0.0
}
