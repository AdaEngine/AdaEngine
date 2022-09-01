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



/// Gear joint definition. This definition requires two existing
/// revolute or prismatic joints (any combination will work).
open class b2GearJointDef : b2JointDef {
    public override init() {
        joint1 = nil
        joint2 = nil
        ratio = 1.0
        super.init()
        type = b2JointType.gearJoint
    }
    
    /// The first revolute/prismatic joint attached to the gear joint.
    open var joint1: b2Joint! = nil
    
    /// The second revolute/prismatic joint attached to the gear joint.
    open var joint2: b2Joint! = nil
    
    /// The gear ratio.
    /// @see b2GearJoint for explanation.
    open var ratio: b2Float = 1.0
}

// MARK: -
/// A gear joint is used to connect two joints together. Either joint
/// can be a revolute or prismatic joint. You specify a gear ratio
/// to bind the motions together:
/// coordinate1 + ratio * coordinate2 = constant
/// The ratio can be negative or positive. If one joint is a revolute joint
/// and the other joint is a prismatic joint, then the ratio will have units
/// of length or units of 1/length.
/// @warning You have to manually destroy the gear joint if joint1 or joint2
/// is destroyed.
open class b2GearJoint : b2Joint {
    open override var anchorA: b2Vec2 {
        return m_bodyA.getWorldPoint(m_localAnchorA)
    }
    open override var anchorB: b2Vec2 {
        return m_bodyB.getWorldPoint(m_localAnchorB)
    }
    
    /// Get the reaction force given the inverse time step.
    /// Unitoverride  is N.
    open override func getReactionForce(inverseTimeStep inv_dt: b2Float) -> b2Vec2 {
        let P = m_impulse * m_JvAC
        return inv_dt * P
    }
    
    /// Get the reaction torque given the inverse time step.
    /// Unit is N*m. This is always zero for a distance joint.
    open override func getReactionTorque(inverseTimeStep inv_dt: b2Float) -> b2Float {
        let L = m_impulse * m_JwA
        return inv_dt * L
    }
    
    /// Get the first joint.
    open var joint1: b2Joint { return m_joint1 }
    
    /// Get the second joint.
    open var joint2: b2Joint { return m_joint2 }
    
    /// Set/Get the gear ratio.
    open func setRatio(_ ratio: b2Float) {
        assert(b2IsValid(ratio))
        m_ratio = ratio
    }
    
    open var ratio: b2Float {
        get {
            return m_ratio
        }
        set {
            setRatio(newValue)
        }
    }
    
    /// Dump joint to dmLog
    open override func dump() {
        let indexA = m_bodyA.m_islandIndex
        let indexB = m_bodyB.m_islandIndex
        
        let index1 = m_joint1.m_index
        let index2 = m_joint2.m_index
        
        print("  b2GearJointDef jd;")
        print("  jd.bodyA = bodies[\(indexA)];")
        print("  jd.bodyB = bodies[\(indexB)];")
        print("  jd.collideConnected = bool(\(m_collideConnected));")
        print("  jd.joint1 = joints[\(index1)];")
        print("  jd.joint2 = joints[\(index2)];")
        print("  jd.ratio = \(m_ratio);")
        print("  joints[\(m_index)] = m_world->createJoint(&jd);")
    }
    
    // MARK: private methods
    init(_ def: b2GearJointDef) {
        m_joint1 = def.joint1
        m_joint2 = def.joint2
        
        m_typeA = m_joint1.type
        m_typeB = m_joint2.type
        super.init(def)
        
        assert(m_typeA == b2JointType.revoluteJoint || m_typeA == b2JointType.prismaticJoint)
        assert(m_typeB == b2JointType.revoluteJoint || m_typeB == b2JointType.prismaticJoint)
        
        var coordinateA: b2Float, coordinateB: b2Float
        
        // TODO_ERIN there might be some problem with the joint edges in b2Joint.
        
        m_bodyC = m_joint1.bodyA
        m_bodyA = m_joint1.bodyB
        
        // Get geometry of joint1
        let xfA = m_bodyA.m_xf
        let aA = m_bodyA.m_sweep.a
        let xfC = m_bodyC.m_xf
        let aC = m_bodyC.m_sweep.a
        
        if m_typeA == b2JointType.revoluteJoint {
            let revolute = def.joint1 as! b2RevoluteJoint
            m_localAnchorC = revolute.m_localAnchorA
            m_localAnchorA = revolute.m_localAnchorB
            m_referenceAngleA = revolute.m_referenceAngle
            m_localAxisC.setZero()
            
            coordinateA = aA - aC - m_referenceAngleA
        }
        else {
            let prismatic = def.joint1 as! b2PrismaticJoint
            m_localAnchorC = prismatic.m_localAnchorA
            m_localAnchorA = prismatic.m_localAnchorB
            m_referenceAngleA = prismatic.m_referenceAngle
            m_localAxisC = prismatic.m_localXAxisA
            
            let pC = m_localAnchorC
            let pA = b2MulT(xfC.q, b2Mul(xfA.q, m_localAnchorA) + (xfA.p - xfC.p))
            coordinateA = b2Dot(pA - pC, m_localAxisC)
        }
        
        m_bodyD = m_joint2.bodyA
        m_bodyB = m_joint2.bodyB
        
        // Get geometry of joint2
        let xfB = m_bodyB.m_xf
        let aB = m_bodyB.m_sweep.a
        let xfD = m_bodyD.m_xf
        let aD = m_bodyD.m_sweep.a
        
        if m_typeB == b2JointType.revoluteJoint {
            let revolute = def.joint2 as! b2RevoluteJoint
            m_localAnchorD = revolute.m_localAnchorA
            m_localAnchorB = revolute.m_localAnchorB
            m_referenceAngleB = revolute.m_referenceAngle
            m_localAxisD.setZero()
            
            coordinateB = aB - aD - m_referenceAngleB
        }
        else {
            let prismatic = def.joint2 as! b2PrismaticJoint
            m_localAnchorD = prismatic.m_localAnchorA
            m_localAnchorB = prismatic.m_localAnchorB
            m_referenceAngleB = prismatic.m_referenceAngle
            m_localAxisD = prismatic.m_localXAxisA
            
            let pD = m_localAnchorD
            let pB = b2MulT(xfD.q, b2Mul(xfB.q, m_localAnchorB) + (xfB.p - xfD.p))
            coordinateB = b2Dot(pB - pD, m_localAxisD)
        }
        
        m_ratio = def.ratio
        
        m_constant = coordinateA + m_ratio * coordinateB
        
        m_impulse = 0.0
        
    }
    
    override func initVelocityConstraints(_ data: inout b2SolverData) {
        m_indexA = m_bodyA.m_islandIndex
        m_indexB = m_bodyB.m_islandIndex
        m_indexC = m_bodyC.m_islandIndex
        m_indexD = m_bodyD.m_islandIndex
        m_lcA = m_bodyA.m_sweep.localCenter
        m_lcB = m_bodyB.m_sweep.localCenter
        m_lcC = m_bodyC.m_sweep.localCenter
        m_lcD = m_bodyD.m_sweep.localCenter
        m_mA = m_bodyA.m_invMass
        m_mB = m_bodyB.m_invMass
        m_mC = m_bodyC.m_invMass
        m_mD = m_bodyD.m_invMass
        m_iA = m_bodyA.m_invI
        m_iB = m_bodyB.m_invI
        m_iC = m_bodyC.m_invI
        m_iD = m_bodyD.m_invI
        
        let aA = data.positions[m_indexA].a
        var vA = data.velocities[m_indexA].v
        var wA = data.velocities[m_indexA].w
        
        let aB = data.positions[m_indexB].a
        var vB = data.velocities[m_indexB].v
        var wB = data.velocities[m_indexB].w
        
        let aC = data.positions[m_indexC].a
        var vC = data.velocities[m_indexC].v
        var wC = data.velocities[m_indexC].w
        
        let aD = data.positions[m_indexD].a
        var vD = data.velocities[m_indexD].v
        var wD = data.velocities[m_indexD].w
        
        let qA = b2Rot(aA), qB = b2Rot(aB), qC = b2Rot(aC), qD = b2Rot(aD)
        
        m_mass = 0.0
        
        if m_typeA == b2JointType.revoluteJoint {
            m_JvAC.setZero()
            m_JwA = 1.0
            m_JwC = 1.0
            m_mass += m_iA + m_iC
        }
        else {
            let u = b2Mul(qC, m_localAxisC)
            let rC = b2Mul(qC, m_localAnchorC - m_lcC)
            let rA = b2Mul(qA, m_localAnchorA - m_lcA)
            m_JvAC = u
            m_JwC = b2Cross(rC, u)
            m_JwA = b2Cross(rA, u)
            m_mass += m_mC + m_mA + m_iC * m_JwC * m_JwC + m_iA * m_JwA * m_JwA
        }
        
        if m_typeB == b2JointType.revoluteJoint {
            m_JvBD.setZero()
            m_JwB = m_ratio
            m_JwD = m_ratio
            m_mass += m_ratio * m_ratio * (m_iB + m_iD)
        }
        else {
            let u = b2Mul(qD, m_localAxisD)
            let rD = b2Mul(qD, m_localAnchorD - m_lcD)
            let rB = b2Mul(qB, m_localAnchorB - m_lcB)
            m_JvBD = m_ratio * u
            m_JwD = m_ratio * b2Cross(rD, u)
            m_JwB = m_ratio * b2Cross(rB, u)
            let mass1 = m_ratio * m_ratio * (m_mD + m_mB)
            let mass2 = m_iD * m_JwD * m_JwD + m_iB * m_JwB * m_JwB
            let mass = mass1 + mass2
            m_mass += mass
        }
        
        // Compute effective mass.
        m_mass = m_mass > 0.0 ? 1.0 / m_mass : 0.0
        
        if data.step.warmStarting {
            vA += (m_mA * m_impulse) * m_JvAC
            wA += m_iA * m_impulse * m_JwA
            vB += (m_mB * m_impulse) * m_JvBD
            wB += m_iB * m_impulse * m_JwB
            vC -= (m_mC * m_impulse) * m_JvAC
            wC -= m_iC * m_impulse * m_JwC
            vD -= (m_mD * m_impulse) * m_JvBD
            wD -= m_iD * m_impulse * m_JwD
        }
        else {
            m_impulse = 0.0
        }
        
        data.velocities[m_indexA].v = vA
        data.velocities[m_indexA].w = wA
        data.velocities[m_indexB].v = vB
        data.velocities[m_indexB].w = wB
        data.velocities[m_indexC].v = vC
        data.velocities[m_indexC].w = wC
        data.velocities[m_indexD].v = vD
        data.velocities[m_indexD].w = wD
    }
    
    override func solveVelocityConstraints(_ data: inout b2SolverData) {
        var vA = data.velocities[m_indexA].v
        var wA = data.velocities[m_indexA].w
        var vB = data.velocities[m_indexB].v
        var wB = data.velocities[m_indexB].w
        var vC = data.velocities[m_indexC].v
        var wC = data.velocities[m_indexC].w
        var vD = data.velocities[m_indexD].v
        var wD = data.velocities[m_indexD].w
        
        var Cdot = b2Dot(m_JvAC, vA - vC) + b2Dot(m_JvBD, vB - vD)
        Cdot += (m_JwA * wA - m_JwC * wC) + (m_JwB * wB - m_JwD * wD)
        
        let impulse = -m_mass * Cdot
        m_impulse += impulse
        
        vA += (m_mA * impulse) * m_JvAC
        wA += m_iA * impulse * m_JwA
        vB += (m_mB * impulse) * m_JvBD
        wB += m_iB * impulse * m_JwB
        vC -= (m_mC * impulse) * m_JvAC
        wC -= m_iC * impulse * m_JwC
        vD -= (m_mD * impulse) * m_JvBD
        wD -= m_iD * impulse * m_JwD
        
        data.velocities[m_indexA].v = vA
        data.velocities[m_indexA].w = wA
        data.velocities[m_indexB].v = vB
        data.velocities[m_indexB].w = wB
        data.velocities[m_indexC].v = vC
        data.velocities[m_indexC].w = wC
        data.velocities[m_indexD].v = vD
        data.velocities[m_indexD].w = wD
    }
    
    // This returns true if the position errors are within tolerance.
    override func solvePositionConstraints(_ data: inout b2SolverData) -> Bool {
        var cA = data.positions[m_indexA].c
        var aA = data.positions[m_indexA].a
        var cB = data.positions[m_indexB].c
        var aB = data.positions[m_indexB].a
        var cC = data.positions[m_indexC].c
        var aC = data.positions[m_indexC].a
        var cD = data.positions[m_indexD].c
        var aD = data.positions[m_indexD].a
        
        let qA = b2Rot(aA), qB = b2Rot(aB), qC = b2Rot(aC), qD = b2Rot(aD)
        
        let linearError: b2Float = 0.0
        
        var coordinateA: b2Float = 0, coordinateB: b2Float = 0
        
        var JvAC = b2Vec2(), JvBD = b2Vec2()
        var JwA: b2Float = 0, JwB: b2Float = 0, JwC: b2Float = 0, JwD: b2Float = 0
        var mass: b2Float = 0.0
        
        if m_typeA == b2JointType.revoluteJoint {
            JvAC.setZero()
            JwA = 1.0
            JwC = 1.0
            mass += m_iA + m_iC
            
            coordinateA = aA - aC - m_referenceAngleA
        }
        else {
            let u = b2Mul(qC, m_localAxisC)
            let rC = b2Mul(qC, m_localAnchorC - m_lcC)
            let rA = b2Mul(qA, m_localAnchorA - m_lcA)
            JvAC = u
            JwC = b2Cross(rC, u)
            JwA = b2Cross(rA, u)
            mass += m_mC + m_mA + m_iC * JwC * JwC + m_iA * JwA * JwA
            
            let pC = m_localAnchorC - m_lcC
            let pA = b2MulT(qC, rA + (cA - cC))
            coordinateA = b2Dot(pA - pC, m_localAxisC)
        }
        
        if m_typeB == b2JointType.revoluteJoint {
            JvBD.setZero()
            JwB = m_ratio
            JwD = m_ratio
            mass += m_ratio * m_ratio * (m_iB + m_iD)
            
            coordinateB = aB - aD - m_referenceAngleB
        }
        else {
            let u = b2Mul(qD, m_localAxisD)
            let rD = b2Mul(qD, m_localAnchorD - m_lcD)
            let rB = b2Mul(qB, m_localAnchorB - m_lcB)
            JvBD = m_ratio * u
            JwD = m_ratio * b2Cross(rD, u)
            JwB = m_ratio * b2Cross(rB, u)
            mass += m_ratio * m_ratio * (m_mD + m_mB) + m_iD * JwD * JwD + m_iB * JwB * JwB
            
            let pD = m_localAnchorD - m_lcD
            let pB = b2MulT(qD, rB + (cB - cD))
            coordinateB = b2Dot(pB - pD, m_localAxisD)
        }
        
        let C = (coordinateA + m_ratio * coordinateB) - m_constant
        
        var impulse: b2Float = 0.0
        if mass > 0.0 {
            impulse = -C / mass
        }
        
        cA += m_mA * impulse * JvAC
        aA += m_iA * impulse * JwA
        cB += m_mB * impulse * JvBD
        aB += m_iB * impulse * JwB
        cC -= m_mC * impulse * JvAC
        aC -= m_iC * impulse * JwC
        cD -= m_mD * impulse * JvBD
        aD -= m_iD * impulse * JwD
        
        data.positions[m_indexA].c = cA
        data.positions[m_indexA].a = aA
        data.positions[m_indexB].c = cB
        data.positions[m_indexB].a = aB
        data.positions[m_indexC].c = cC
        data.positions[m_indexC].a = aC
        data.positions[m_indexD].c = cD
        data.positions[m_indexD].a = aD
        
        // TODO_ERIN not implemented
        return linearError < b2_linearSlop
    }
    
    // MARK: private variables
    var m_joint1: b2Joint
    var m_joint2: b2Joint
    
    var m_typeA: b2JointType
    var m_typeB: b2JointType
    
    // Body A is connected to body C
    // Body B is connected to body D
    var m_bodyC: b2Body!
    var m_bodyD: b2Body!
    
    // Solver shared
    var m_localAnchorA = b2Vec2()
    var m_localAnchorB = b2Vec2()
    var m_localAnchorC = b2Vec2()
    var m_localAnchorD = b2Vec2()
    
    var m_localAxisC = b2Vec2()
    var m_localAxisD = b2Vec2()
    
    var m_referenceAngleA: b2Float = 0.0
    var m_referenceAngleB: b2Float = 0.0
    
    var m_constant: b2Float = 0.0
    var m_ratio: b2Float = 0.0
    
    var m_impulse: b2Float = 0.0
    
    // Solver temp
    var m_indexA: Int = 0, m_indexB: Int = 0, m_indexC: Int = 0, m_indexD: Int = 0
    var m_lcA = b2Vec2(), m_lcB = b2Vec2(), m_lcC = b2Vec2(), m_lcD = b2Vec2()
    var m_mA: b2Float = 0.0, m_mB: b2Float = 0.0, m_mC: b2Float = 0.0, m_mD: b2Float = 0.0
    var m_iA: b2Float = 0.0, m_iB: b2Float = 0.0, m_iC: b2Float = 0.0, m_iD: b2Float = 0.0
    var m_JvAC = b2Vec2(), m_JvBD = b2Vec2()
    var m_JwA: b2Float = 0.0, m_JwB: b2Float = 0.0, m_JwC: b2Float = 0.0, m_JwD: b2Float = 0.0
    var m_mass: b2Float = 0.0
}
