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



/// Motor joint definition.
open class b2MotorJointDef : b2JointDef {
    public override init() {
        linearOffset = b2Vec2()
        angularOffset = 0.0
        maxForce = 1.0
        maxTorque = 1.0
        correctionFactor = 0.3
        super.init()
        type = b2JointType.motorJoint
    }
    
    /// Initialize the bodies and offsets using the current transforms.
    public convenience init(bodyA: b2Body, bodyB: b2Body) {
        self.init()
        initialize(bodyA: bodyA, bodyB: bodyB)
    }
    
    /// Initialize the bodies and offsets using the current transforms.
    open func initialize(bodyA: b2Body, bodyB: b2Body) {
        self.bodyA = bodyA
        self.bodyB = bodyB
        let xB = bodyB.position
        linearOffset = bodyA.getLocalPoint(xB)
        
        let angleA = bodyA.angle
        let angleB = bodyB.angle
        angularOffset = angleB - angleA
    }
    
    /// Position of bodyB minus the position of bodyA, in bodyA's frame, in meters.
    open var linearOffset: b2Vec2
    
    /// The bodyB angle minus bodyA angle in radians.
    open var angularOffset: b2Float
    
    /// The maximum motor force in N.
    open var maxForce: b2Float
    
    /// The maximum motor torque in N-m.
    open var maxTorque: b2Float
    
    /// Position correction factor in the range [0,1].
    open var correctionFactor: b2Float
}

// MARK: -
/// A motor joint is used to control the relative motion
/// between two bodies. A typical usage is to control the movement
/// of a dynamic body with respect to the ground.
open class b2MotorJoint : b2Joint {
    open override var anchorA: b2Vec2 {
        return m_bodyA.position
    }
    open override var anchorB: b2Vec2 {
        return m_bodyB.position
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
    
    /// Set/get the target linear offset, in frame A, in meters.
    open func setLinearOffset(_ linearOffset: b2Vec2) {
        if linearOffset.x != m_linearOffset.x || linearOffset.y != m_linearOffset.y {
            m_bodyA.setAwake(true)
            m_bodyB.setAwake(true)
            m_linearOffset = linearOffset
        }
    }
    open var linearOffset: b2Vec2 {
        get {
            return m_linearOffset
        }
        set {
            setLinearOffset(newValue)
        }
    }
    
    /// Set/get the target angular offset, in radians.
    open func setAngularOffset(_ angularOffset: b2Float) {
        if angularOffset != m_angularOffset {
            m_bodyA.setAwake(true)
            m_bodyB.setAwake(true)
            m_angularOffset = angularOffset
        }
    }
    open var angularOffset: b2Float {
        get {
            return m_angularOffset
        }
        set {
            setAngularOffset(newValue)
        }
    }
    
    /// Set the maximum friction force in N.
    open func setMaxForce(_ force: b2Float) {
        assert(b2IsValid(force) && force >= 0.0)
        m_maxForce = force
    }
    
    /// Get the maximum friction force in N.
    open var maxForce: b2Float {
        get {
            return m_maxForce
        }
        set {
            setMaxForce(newValue)
        }
    }
    
    /// Set the maximum friction torque in N*m.
    open func setMaxTorque(_ torque: b2Float) {
        assert(b2IsValid(torque) && torque >= 0.0)
        m_maxTorque = torque
    }
    
    /// Get the maximum friction torque in N*m.
    open var maxTorque: b2Float {
        get {
            return m_maxTorque
        }
        set {
            setMaxTorque(newValue)
        }
    }
    
    /// Set the position correction factor in the range [0,1].
    open func setCorrectionFactor(_ factor: b2Float) {
        assert(b2IsValid(factor) && 0.0 <= factor && factor <= 1.0)
        m_correctionFactor = factor
    }
    
    /// Get the position correction factor in the range [0,1].
    open var correctionFactor: b2Float {
        get {
            return m_correctionFactor
        }
        set {
            setCorrectionFactor(newValue)
        }
    }
    
    /// Dump to b2Log
    open override func dump() {
        let indexA = m_bodyA.m_islandIndex
        let indexB = m_bodyB.m_islandIndex
        
        print("  b2MotorJointDef jd;")
        print("  jd.bodyA = bodies[\(indexA)];")
        print("  jd.bodyB = bodies[\(indexB)];")
        print("  jd.collideConnected = bool(\(m_collideConnected));")
        print("  jd.linearOffset.set(\(m_linearOffset.x), \(m_linearOffset.y));")
        print("  jd.angularOffset = \(m_angularOffset);")
        print("  jd.maxForce = \(m_maxForce);")
        print("  jd.maxTorque = \(m_maxTorque);")
        print("  jd.correctionFactor = \(m_correctionFactor);")
        print("  joints[\(m_index)] = m_world->createJoint(&jd);\n")
    }
    
    // MARK: private methods
    init(_ def: b2MotorJointDef) {
        m_linearOffset = def.linearOffset
        m_angularOffset = def.angularOffset
        
        m_linearImpulse = b2Vec2()
        m_angularImpulse = 0.0
        
        m_maxForce = def.maxForce
        m_maxTorque = def.maxTorque
        m_correctionFactor = def.correctionFactor
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
        
        // Compute the effective mass matrix.
        m_rA = b2Mul(qA, -m_localCenterA)
        m_rB = b2Mul(qB, -m_localCenterB)
        
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
        
        m_linearError = cB + m_rB - cA - m_rA - b2Mul(qA, m_linearOffset)
        m_angularError = aB - aA - m_angularOffset
        
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
        let inv_h = data.step.inv_dt
        
        // Solve angular friction
        //{
        b2Locally {
            let Cdot = wB - wA + inv_h * self.m_correctionFactor * self.m_angularError
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
            let Cdot = vB + b2Cross(wB, self.m_rB) - vA - b2Cross(wA, self.m_rA) + inv_h * self.m_correctionFactor * self.m_linearError
            
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
    // Solver shared
    var m_linearOffset: b2Vec2
    var m_angularOffset: b2Float
    var m_linearImpulse: b2Vec2
    var m_angularImpulse: b2Float
    var m_maxForce: b2Float
    var m_maxTorque: b2Float
    var m_correctionFactor: b2Float
    
    // Solver temp
    var m_indexA: Int = 0
    var m_indexB: Int = 0
    var m_rA = b2Vec2()
    var m_rB = b2Vec2()
    var m_localCenterA = b2Vec2()
    var m_localCenterB = b2Vec2()
    var m_linearError = b2Vec2()
    var m_angularError: b2Float = 0
    var m_invMassA: b2Float = 0
    var m_invMassB: b2Float = 0
    var m_invIA: b2Float = 0
    var m_invIB: b2Float = 0
    var m_linearMass = b2Mat22()
    var m_angularMass: b2Float = 0
}
