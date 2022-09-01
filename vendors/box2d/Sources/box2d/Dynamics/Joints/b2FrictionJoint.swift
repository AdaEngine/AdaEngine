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



/// Friction joint definition.
open class b2FrictionJointDef : b2JointDef {
    public override init() {
        localAnchorA = b2Vec2()
        localAnchorB = b2Vec2()
        maxForce = 0.0
        maxTorque = 0.0
        super.init()
        type = b2JointType.frictionJoint
    }
    
    /// Initialize the bodies, anchors, axis, and reference angle using the world
    /// anchor and world axis.
    public convenience init(bodyA: b2Body, bodyB: b2Body, anchor: b2Vec2) {
        self.init()
        initialize(bodyA: bodyA, bodyB: bodyB, anchor: anchor)
    }
    
    /// Initialize the bodies, anchors, axis, and reference angle using the world
    /// anchor and world axis.
    open func initialize(bodyA bA: b2Body, bodyB bB: b2Body, anchor: b2Vec2) {
        bodyA = bA
        bodyB = bB
        localAnchorA = bodyA.getLocalPoint(anchor)
        localAnchorB = bodyB.getLocalPoint(anchor)
    }
    
    /// The local anchor point relative to bodyA's origin.
    open var localAnchorA: b2Vec2
    
    /// The local anchor point relative to bodyB's origin.
    open var localAnchorB: b2Vec2
    
    /// The maximum friction force in N.
    open var maxForce: b2Float
    
    /// The maximum friction torque in N-m.
    open var maxTorque: b2Float
}

// MARK: -
/// Friction joint. This is used for top-down friction.
/// It provides 2D translational friction and angular friction.
open class b2FrictionJoint : b2Joint {
    open override var anchorA: b2Vec2 {
        return m_bodyA.getWorldPoint(m_localAnchorA)
    }
    open override var anchorB: b2Vec2 {
        return m_bodyB.getWorldPoint(m_localAnchorB)
    }
    
    /// Get the reaction force given the inverse time step.
    /// Unitoverride  is N.
    open override func getReactionForce(inverseTimeStep inv_dt: b2Float) -> b2Vec2 {
        return inv_dt * m_linearImpulse
    }
    
    /// Get the reaction torque given the inverse time step.
    /// Unit is N*m. This is always zero for a distance joint.
    open override func getReactionTorque(inverseTimeStep inv_dt: b2Float) -> b2Float {
        return inv_dt * m_angularImpulse
    }
    
    /// The local anchor point relative to bodyA's origin.
    open var localAnchorA: b2Vec2  { return m_localAnchorA }
    
    /// The local anchor point relative to bodyB's origin.
    open var localAnchorB: b2Vec2  { return m_localAnchorB }
    
    /// Set the maximum friction force in N.
    open func setMaxForce(_ force: b2Float) {
        assert(b2IsValid(force) && force >= 0.0)
        m_maxForce = force
    }
    
    /// Get the maximum friction force in N.
    open var maxForce: b2Float {
        return m_maxForce
    }
    
    /// Set the maximum friction torque in N*m.
    open func setMaxTorque(_ torque: b2Float) {
        assert(b2IsValid(torque) && torque >= 0.0)
        m_maxTorque = torque
    }
    
    /// Get the maximum friction torque in N*m.
    open var maxTorque: b2Float {
        return m_maxTorque
    }
    
    /// Dump joint to dmLog
    open override func dump() {
        let indexA = m_bodyA.m_islandIndex
        let indexB = m_bodyB.m_islandIndex
        
        print("  b2FrictionJointDef jd;\n")
        print("  jd.bodyA = bodies[\(indexA)];")
        print("  jd.bodyB = bodies[\(indexB)];")
        print("  jd.collideConnected = bool(\(m_collideConnected));")
        print("  jd.localAnchorA.set(\(m_localAnchorA.x), \(m_localAnchorA.y));")
        print("  jd.localAnchorB.set(\(m_localAnchorB.x), \(m_localAnchorB.y));")
        print("  jd.maxForce = \(m_maxForce);")
        print("  jd.maxTorque = \(m_maxTorque);")
        print("  joints[\(m_index)] = m_world->createJoint(&jd);")
    }
    
    // MARK: private methods
    init(_ def: b2FrictionJointDef) {
        m_localAnchorA = def.localAnchorA
        m_localAnchorB = def.localAnchorB
        
        m_linearImpulse = b2Vec2(0.0, 0.0)
        m_angularImpulse = 0.0
        
        m_maxForce = def.maxForce
        m_maxTorque = def.maxTorque
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
        
        let aA = data.positions[m_indexA].a
        var vA = data.velocities[m_indexA].v
        var wA = data.velocities[m_indexA].w
        
        let aB = data.positions[m_indexB].a
        var vB = data.velocities[m_indexB].v
        var wB = data.velocities[m_indexB].w
        
        let qA = b2Rot(aA), qB = b2Rot(aB)
        
        // Compute the effective mass matrix.
        m_rA = b2Mul(qA, m_localAnchorA - m_localCenterA)
        m_rB = b2Mul(qB, m_localAnchorB - m_localCenterB)
        
        // J = [-I -r1_skew I r2_skew]
        //     [ 0       -1 0       1]
        // r_skew = [-ry; rx]
        
        // Matlab
        // K = [ mA+r1y^2*iA+mB+r2y^2*iB,  -r1y*iA*r1x-r2y*iB*r2x,          -r1y*iA-r2y*iB]
        //     [  -r1y*iA*r1x-r2y*iB*r2x, mA+r1x^2*iA+mB+r2x^2*iB,           r1x*iA+r2x*iB]
        //     [          -r1y*iA-r2y*iB,           r1x*iA+r2x*iB,                   iA+iB]
        
        let mA = m_invMassA, mB = m_invMassB
        let iA = m_invIA, iB = m_invIB
        
        var K = b2Mat22()
        K.ex.x = mA + mB + iA * m_rA.y * m_rA.y + iB * m_rB.y * m_rB.y
        K.ex.y = -iA * m_rA.x * m_rA.y - iB * m_rB.x * m_rB.y
        K.ey.x = K.ex.y
        K.ey.y = mA + mB + iA * m_rA.x * m_rA.x + iB * m_rB.x * m_rB.x
        
        m_linearMass = K.getInverse()
        
        m_angularMass = iA + iB
        if m_angularMass > 0.0 {
            m_angularMass = 1.0 / m_angularMass
        }
        
        if data.step.warmStarting {
            // Scale impulses to support a variable time step.
            m_linearImpulse *= data.step.dtRatio
            m_angularImpulse *= data.step.dtRatio
            
            let P = b2Vec2(m_linearImpulse.x, m_linearImpulse.y)
            vA -= mA * P
            wA -= iA * (b2Cross(m_rA, P) + m_angularImpulse)
            vB += mB * P
            wB += iB * (b2Cross(m_rB, P) + m_angularImpulse)
        }
        else {
            m_linearImpulse.setZero()
            m_angularImpulse = 0.0
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
        
        let mA = m_invMassA, mB = m_invMassB
        let iA = m_invIA, iB = m_invIB
        
        let h = data.step.dt
        
        // Solve angular friction
        b2Locally {
            let Cdot = wB - wA
            var impulse = -self.m_angularMass * Cdot
            
            let oldImpulse = self.m_angularImpulse
            let maxImpulse = h * self.m_maxTorque
            self.m_angularImpulse = b2Clamp(self.m_angularImpulse + impulse, -maxImpulse, maxImpulse)
            impulse = self.m_angularImpulse - oldImpulse
            
            wA -= iA * impulse
            wB += iB * impulse
        }
        
        // Solve linear friction
        b2Locally {
            let Cdot = vB + b2Cross(wB, self.m_rB) - vA - b2Cross(wA, self.m_rA)
            
            var impulse = -b2Mul(self.m_linearMass, Cdot)
            let oldImpulse = self.m_linearImpulse
            self.m_linearImpulse += impulse
            
            let maxImpulse = h * self.m_maxForce
            
            if self.m_linearImpulse.lengthSquared() > maxImpulse * maxImpulse {
                self.m_linearImpulse.normalize()
                self.m_linearImpulse *= maxImpulse
            }
            
            impulse = self.m_linearImpulse - oldImpulse
            
            vA -= mA * impulse
            wA -= iA * b2Cross(self.m_rA, impulse)
            
            vB += mB * impulse
            wB += iB * b2Cross(self.m_rB, impulse)
        }
        
        data.velocities[m_indexA].v = vA
        data.velocities[m_indexA].w = wA
        data.velocities[m_indexB].v = vB
        data.velocities[m_indexB].w = wB
    }
    
    // This returns true if the position errors are within tolerance.
    override func solvePositionConstraints(_ data: inout b2SolverData) -> Bool {
        return true
    }
    
    // MARK: private variables
    var m_localAnchorA: b2Vec2
    var m_localAnchorB: b2Vec2
    
    // Solver shared
    var m_linearImpulse: b2Vec2
    var m_angularImpulse: b2Float
    var m_maxForce: b2Float
    var m_maxTorque: b2Float
    
    // Solver temp
    var m_indexA: Int = 0
    var m_indexB: Int = 0
    var m_rA = b2Vec2()
    var m_rB = b2Vec2()
    var m_localCenterA = b2Vec2()
    var m_localCenterB = b2Vec2()
    var m_invMassA: b2Float = 0.0
    var m_invMassB: b2Float = 0.0
    var m_invIA: b2Float = 0.0
    var m_invIB: b2Float = 0.0
    var m_linearMass = b2Mat22()
    var m_angularMass: b2Float = 0.0
}
