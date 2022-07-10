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



/// Distance joint definition. This requires defining an
/// anchor point on both bodies and the non-zero length of the
/// distance joint. The definition uses local anchor points
/// so that the initial configuration can violate the constraint
/// slightly. This helps when saving and loading a game.
/// @warning Do not use a zero or short length.
open class b2DistanceJointDef : b2JointDef {
    public override init() {
        localAnchorA = b2Vec2(0.0, 0.0)
        localAnchorB = b2Vec2(0.0, 0.0)
        length = 1.0
        frequencyHz = 0.0
        dampingRatio = 0.0
        super.init()
        type = b2JointType.distanceJoint
    }
    
    /// Initialize the bodies, anchors, and length using the world
    /// anchors.
    public convenience init(bodyA: b2Body, bodyB: b2Body, anchorA: b2Vec2, anchorB: b2Vec2) {
        self.init()
        initialize(bodyA: bodyA, bodyB: bodyB, anchorA: anchorA, anchorB: anchorB)
    }
    
    /// Initialize the bodies, anchors, and length using the world
    /// anchors.
    open func initialize(bodyA bA: b2Body, bodyB bB: b2Body, anchorA: b2Vec2, anchorB: b2Vec2) {
        bodyA = bA
        bodyB = bB
        localAnchorA = bodyA.getLocalPoint(anchorA)
        localAnchorB = bodyB.getLocalPoint(anchorB)
        let d = anchorB - anchorA
        length = d.length()
    }
    
    /// The local anchor point relative to bodyA's origin.
    open var localAnchorA = b2Vec2()
    
    /// The local anchor point relative to bodyB's origin.
    open var localAnchorB = b2Vec2()
    
    /// The natural length between the anchor points.
    open var length: b2Float = 1.0
    
    /// The mass-spring-damper frequency in Hertz. A value of 0
    /// disables softness.
    open var frequencyHz: b2Float = 0.0
    
    /// The damping ratio. 0 = no damping, 1 = critical damping.
    open var dampingRatio: b2Float = 0.0
}

// MARK: -
/// A distance joint constrains two points on two bodies
/// to remain at a fixed distance from each other. You can view
/// this as a massless, rigid rod.
open class b2DistanceJoint : b2Joint {
    open override var anchorA: b2Vec2 {
        return m_bodyA.getWorldPoint(m_localAnchorA)
    }
    open override var anchorB: b2Vec2 {
        return m_bodyB.getWorldPoint(m_localAnchorB)
    }
    
    /// Get the reaction force given the inverse time step.
    /// Unitoverride  is N.
    open override func getReactionForce(inverseTimeStep inv_dt: b2Float) -> b2Vec2 {
        let F = (inv_dt * m_impulse) * m_u
        return F
    }
    
    /// Get the reaction torque given the inverse time step.
    /// Unit is N*m. This is always zero for a distance joint.
    open override func getReactionTorque(inverseTimeStep inv_dt: b2Float) -> b2Float {
        return 0.0
    }
    
    /// The local anchor point relative to bodyA's origin.
    open var localAnchorA: b2Vec2  { return m_localAnchorA }
    
    /// The local anchor point relative to bodyB's origin.
    open var localAnchorB: b2Vec2  { return m_localAnchorB }
    
    /// Set/get the natural length.
    /// Manipulating the length can lead to non-physical behavior when the frequency is zero.
    open func setLength(_ length: b2Float) {
        m_length = length
    }
    open var length: b2Float {
        return m_length
    }
    
    /// Set/get frequency in Hz.
    open func setFrequency(_ hz: b2Float) {
        m_frequencyHz = hz
    }
    open var frequency: b2Float {
        return m_frequencyHz
    }
    
    /// Set/get damping ratio.
    open func setDampingRatio(_ ratio: b2Float) {
        m_dampingRatio = ratio
    }
    open var dampingRatio: b2Float {
        return m_dampingRatio
    }
    
    /// Dump joint to dmLog
    open override func dump() {
        let indexA = m_bodyA.m_islandIndex
        let indexB = m_bodyB.m_islandIndex
        
        print("  b2DistanceJointDef jd;")
        print("  jd.bodyA = bodies[\(indexA)];")
        print("  jd.bodyB = bodies[\(indexB)];")
        print("  jd.collideConnected = bool(\(m_collideConnected));")
        print("  jd.localAnchorA.set(\(m_localAnchorA.x), \(m_localAnchorA.y);")
        print("  jd.localAnchorB.set(\(m_localAnchorB.x), \(m_localAnchorB.y);")
        print("  jd.length = \(m_length);")
        print("  jd.frequencyHz = \(m_frequencyHz);")
        print("  jd.dampingRatio = \(m_dampingRatio);")
        print("  joints[\(m_index)] = m_world->createJoint(&jd);")
    }
    
    // MARK: private methods
    init(_ def: b2DistanceJointDef) {
        m_localAnchorA = def.localAnchorA
        m_localAnchorB = def.localAnchorB
        m_length = def.length
        m_frequencyHz = def.frequencyHz
        m_dampingRatio = def.dampingRatio
        m_impulse = 0.0
        m_gamma = 0.0
        m_bias = 0.0
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
        m_u = cB + m_rB - cA - m_rA
        
        // Handle singularity.
        let length = m_u.length()
        if length > b2_linearSlop {
            m_u *= 1.0 / length
        }
        else {
            m_u.set(0.0, 0.0)
        }
        
        let crAu = b2Cross(m_rA, m_u)
        let crBu = b2Cross(m_rB, m_u)
        var invMass = m_invMassA + m_invIA * crAu * crAu + m_invMassB + m_invIB * crBu * crBu
        
        // Compute the effective mass matrix.
        m_mass = invMass != 0.0 ? 1.0 / invMass : 0.0
        
        if m_frequencyHz > 0.0 {
            let C = length - m_length
            
            // Frequency
            let omega = 2.0 * b2_pi * m_frequencyHz
            
            // Damping coefficient
            let d = 2.0 * m_mass * m_dampingRatio * omega
            
            // Spring stiffness
            let k = m_mass * omega * omega
            
            // magic formulas
            let h = data.step.dt
            m_gamma = h * (d + h * k)
            m_gamma = m_gamma != 0.0 ? 1.0 / m_gamma : 0.0
            m_bias = C * h * k * m_gamma
            
            invMass += m_gamma
            m_mass = invMass != 0.0 ? 1.0 / invMass : 0.0
        }
        else {
            m_gamma = 0.0
            m_bias = 0.0
        }
        
        if data.step.warmStarting {
            // Scale the impulse to support a variable time step.
            m_impulse *= data.step.dtRatio
            
            let P = m_impulse * m_u
            vA -= m_invMassA * P
            wA -= m_invIA * b2Cross(m_rA, P)
            vB += m_invMassB * P
            wB += m_invIB * b2Cross(m_rB, P)
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
        
        // Cdot = dot(u, v + cross(w, r))
        let vpA = vA + b2Cross(wA, m_rA)
        let vpB = vB + b2Cross(wB, m_rB)
        let Cdot = b2Dot(m_u, vpB - vpA)
        
        let impulse = -m_mass * (Cdot + m_bias + m_gamma * m_impulse)
        m_impulse += impulse
        
        let P = impulse * m_u
        vA -= m_invMassA * P
        wA -= m_invIA * b2Cross(m_rA, P)
        vB += m_invMassB * P
        wB += m_invIB * b2Cross(m_rB, P)
        
        data.velocities[m_indexA].v = vA
        data.velocities[m_indexA].w = wA
        data.velocities[m_indexB].v = vB
        data.velocities[m_indexB].w = wB
    }
    
    // This returns true if the position errors are within tolerance.
    override func solvePositionConstraints(_ data: inout b2SolverData) -> Bool {
        if m_frequencyHz > 0.0 {
            // There is no position correction for soft distance constraints.
            return true
        }
        
        var cA = data.positions[m_indexA].c
        var aA = data.positions[m_indexA].a
        var cB = data.positions[m_indexB].c
        var aB = data.positions[m_indexB].a
        
        let qA = b2Rot(aA), qB = b2Rot(aB)
        
        let rA = b2Mul(qA, m_localAnchorA - m_localCenterA)
        let rB = b2Mul(qB, m_localAnchorB - m_localCenterB)
        var u = cB + rB - cA - rA
        
        let length = u.normalize()
        var C = length - m_length
        C = b2Clamp(C, -b2_maxLinearCorrection, b2_maxLinearCorrection)
        
        let impulse = -m_mass * C
        let P = impulse * u
        
        cA -= m_invMassA * P
        aA -= m_invIA * b2Cross(rA, P)
        cB += m_invMassB * P
        aB += m_invIB * b2Cross(rB, P)
        
        data.positions[m_indexA].c = cA
        data.positions[m_indexA].a = aA
        data.positions[m_indexB].c = cB
        data.positions[m_indexB].a = aB
        
        return abs(C) < b2_linearSlop
    }
    
    // MARK: private variables
    var m_frequencyHz: b2Float
    var m_dampingRatio: b2Float
    var m_bias: b2Float
    
    // Solver shared
    var m_localAnchorA: b2Vec2
    var m_localAnchorB: b2Vec2
    var m_gamma: b2Float
    var m_impulse: b2Float
    var m_length: b2Float
    
    // Solver temp
    var m_indexA: Int = 0
    var m_indexB: Int = 0
    var m_u = b2Vec2()
    var m_rA = b2Vec2()
    var m_rB = b2Vec2()
    var m_localCenterA = b2Vec2()
    var m_localCenterB = b2Vec2()
    var m_invMassA : b2Float = 0.0
    var m_invMassB : b2Float = 0.0
    var m_invIA : b2Float = 0.0
    var m_invIB: b2Float = 0.0
    var m_mass: b2Float = 0.0
}
