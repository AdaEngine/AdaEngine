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



/// Rope joint definition. This requires two body anchor points and
/// a maximum lengths.
/// Note: by default the connected objects will not collide.
/// see collideConnected in b2JointDef.
open class b2RopeJointDef : b2JointDef {
    public override init() {
        localAnchorA = b2Vec2(-1.0, 0.0)
        localAnchorB = b2Vec2(1.0, 0.0)
        maxLength = 0.0
        super.init()
        type = b2JointType.ropeJoint
    }
    
    /// The local anchor point relative to bodyA's origin.
    open var localAnchorA: b2Vec2
    
    /// The local anchor point relative to bodyB's origin.
    open var localAnchorB: b2Vec2
    
    /// The maximum length of the rope.
    /// Warning: this must be larger than b2_linearSlop or
    /// the joint will have no effect.
    open var maxLength: b2Float
}

// MARK: -
/// A rope joint enforces a maximum distance between two points
/// on two bodies. It has no other effect.
/// Warning: if you attempt to change the maximum length during
/// the simulation you will get some non-physical behavior.
/// A model that would allow you to dynamically modify the length
/// would have some sponginess, so I chose not to implement it
/// that way. See b2DistanceJoint if you want to dynamically
/// control length.
open class b2RopeJoint : b2Joint {
    open override var anchorA: b2Vec2 {
        return m_bodyA.getWorldPoint(m_localAnchorA)
    }
    open override var anchorB: b2Vec2 {
        return m_bodyB.getWorldPoint(m_localAnchorB)
    }
    
    open override func getReactionForce(inverseTimeStep inv_dt: b2Float) -> b2Vec2 {
        let F = (inv_dt * m_impulse) * m_u
        return F
    }
    open override func getReactionTorque(inverseTimeStep inv_dt: b2Float) -> b2Float {
        return 0.0
    }
    
    /// The local anchor point relative to bodyA's origin.
    open var localAnchorA: b2Vec2  { return m_localAnchorA }
    
    /// The local anchor point relative to bodyB's origin.
    open var localAnchorB: b2Vec2  { return m_localAnchorB }
    
    /// Set/Get the maximum length of the rope.
    open func setMaxLength(_ length: b2Float) {
        m_maxLength = length
    }
    open var maxLength: b2Float {
        get {
            return m_maxLength
        }
        set {
            setMaxLength(newValue)
        }
    }
    
    open var limitState: b2LimitState {
        return m_state
    }
    
    /// Dump joint to dmLog
    open override func dump() {
        let indexA = m_bodyA.m_islandIndex
        let indexB = m_bodyB.m_islandIndex
        
        print("  b2RopeJointDef jd;")
        print("  jd.bodyA = bodies[\(indexA)];")
        print("  jd.bodyB = bodies[\(indexB)];")
        print("  jd.collideConnected = bool(\(m_collideConnected));")
        print("  jd.localAnchorA.set(\(m_localAnchorA.x), \(m_localAnchorA.y));")
        print("  jd.localAnchorB.set(\(m_localAnchorB.x), \(m_localAnchorB.y));")
        print("  jd.maxLength = \(m_maxLength);")
        print("  joints[\(m_index)] = m_world->createJoint(&jd);")
    }
    
    // MARK: private methods
    
    init(_ def: b2RopeJointDef) {
        m_localAnchorA = def.localAnchorA
        m_localAnchorB = def.localAnchorB
        
        m_maxLength = def.maxLength
        
        m_mass = 0.0
        m_impulse = 0.0
        m_state = b2LimitState.inactiveLimit
        m_length = 0.0
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
        
        m_length = m_u.length()
        
        let C = m_length - m_maxLength
        if C > 0.0 {
            m_state = b2LimitState.atUpperLimit
        }
        else {
            m_state = b2LimitState.inactiveLimit
        }
        
        if m_length > b2_linearSlop {
            m_u *= 1.0 / m_length
        }
        else {
            m_u.setZero()
            m_mass = 0.0
            m_impulse = 0.0
            return
        }
        
        // Compute effective mass.
        let crA = b2Cross(m_rA, m_u)
        let crB = b2Cross(m_rB, m_u)
        let invMass = m_invMassA + m_invIA * crA * crA + m_invMassB + m_invIB * crB * crB
        
        m_mass = invMass != 0.0 ? 1.0 / invMass : 0.0
        
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
        let C = m_length - m_maxLength
        var Cdot = b2Dot(m_u, vpB - vpA)
        
        // Predictive constraint.
        if C < 0.0 {
            Cdot += data.step.inv_dt * C
        }
        
        var impulse = -m_mass * Cdot
        let oldImpulse = m_impulse
        m_impulse = min(0.0, m_impulse + impulse)
        impulse = m_impulse - oldImpulse
        
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
    override func solvePositionConstraints(_ data: inout b2SolverData) -> Bool {
        var cA = data.positions[m_indexA].c
        var aA = data.positions[m_indexA].a
        var cB = data.positions[m_indexB].c
        var aB = data.positions[m_indexB].a
        
        let qA = b2Rot(aA), qB = b2Rot(aB)
        
        let rA = b2Mul(qA, m_localAnchorA - m_localCenterA)
        let rB = b2Mul(qB, m_localAnchorB - m_localCenterB)
        var u = cB + rB - cA - rA
        
        let length = u.normalize()
        var C = length - m_maxLength
        
        C = b2Clamp(C, 0.0, b2_maxLinearCorrection)
        
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
        
        return length - m_maxLength < b2_linearSlop
    }
    
    // MARK: private variables
    
    // Solver shared
    var m_localAnchorA: b2Vec2
    var m_localAnchorB: b2Vec2
    var m_maxLength: b2Float
    var m_length: b2Float
    var m_impulse: b2Float
    
    // Solver temp
    var m_indexA: Int = 0
    var m_indexB: Int = 0
    var m_u = b2Vec2()
    var m_rA = b2Vec2()
    var m_rB = b2Vec2()
    var m_localCenterA = b2Vec2()
    var m_localCenterB = b2Vec2()
    var m_invMassA: b2Float = 0.0
    var m_invMassB: b2Float = 0.0
    var m_invIA: b2Float = 0.0
    var m_invIB: b2Float = 0.0
    var m_mass: b2Float = 0.0
    var m_state = b2LimitState.inactiveLimit
}

