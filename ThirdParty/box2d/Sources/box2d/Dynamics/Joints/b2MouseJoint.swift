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



/// Mouse joint definition. This requires a world target point,
/// tuning parameters, and the time step.
open class b2MouseJointDef : b2JointDef {
    public override init() {
        target = b2Vec2()
        maxForce = 0.0
        frequencyHz = 5.0
        dampingRatio = 0.7
        super.init()
        type = b2JointType.mouseJoint
    }
    
    /// The initial world target point. This is assumed
    /// to coincide with the body anchor initially.
    open var target: b2Vec2
    
    /// The maximum constraint force that can be exerted
    /// to move the candidate body. Usually you will express
    /// as some multiple of the weight (multiplier * mass * gravity).
    open var maxForce: b2Float
    
    /// The response speed.
    open var frequencyHz: b2Float
    
    /// The damping ratio. 0 = no damping, 1 = critical damping.
    open var dampingRatio: b2Float
}

// MARK: -
/// A mouse joint is used to make a point on a body track a
/// specified world point. This a soft constraint with a maximum
/// force. This allows the constraint to stretch and without
/// applying huge forces.
/// NOTE: this joint is not documented in the manual because it was
/// developed to be used in the testbed. If you want to learn how to
/// use the mouse joint, look at the testbed.
open class b2MouseJoint : b2Joint {
    /// Implements b2Joint.
    open override var anchorA: b2Vec2 {
        return m_targetA
    }
    
    /// Implements b2Joint.
    open override var anchorB: b2Vec2 {
        return m_bodyB.getWorldPoint(m_localAnchorB)
    }
    
    /// Implements b2Joint.
    open override func getReactionForce(inverseTimeStep inv_dt: b2Float) -> b2Vec2 {
        return inv_dt * m_impulse
    }
    
    /// Implements b2Joint.
    open override func getReactionTorque(inverseTimeStep inv_dt: b2Float) -> b2Float {
        return inv_dt * 0.0
    }
    
    /// Use this to update the target point.
    open func setTarget(_ target: b2Vec2) {
        if m_bodyB.isAwake == false {
            m_bodyB.setAwake(true)
        }
        m_targetA = target
    }
    open var target: b2Vec2 {
        get {
            return m_targetA
        }
        set {
            setTarget(newValue)
        }
    }
    
    /// Set/get the maximum force in Newtons.
    open func setMaxForce(_ force: b2Float) {
        m_maxForce = force
    }
    open var maxForce: b2Float {
        get {
            return m_maxForce
        }
        set {
            setMaxForce(newValue)
        }
    }
    
    /// Set/get the frequency in Hertz.
    open func setFrequency(_ hz: b2Float) {
        m_frequencyHz = hz
    }
    open var frequency: b2Float {
        get {
            return m_frequencyHz
        }
        set {
            setFrequency(newValue)
        }
    }
    
    /// Set/get the damping ratio (dimensionless).
    open func setDampingRatio(_ ratio: b2Float) {
        m_dampingRatio = ratio
    }
    open var dampingRatio: b2Float {
        get {
            return m_dampingRatio
        }
        set {
            setDampingRatio(newValue)
        }
    }
    
    /// The mouse joint does not support dumping.
    open override func dump() { print("Mouse joint dumping is not supported.") }
    
    /// Implement b2Joint::ShiftOrigin
    open override func shiftOrigin(_ newOrigin: b2Vec2) {
        m_targetA -= newOrigin
    }
    
    // MARK: private methods
    init(_ def: b2MouseJointDef) {
        assert(def.target.isValid())
        assert(b2IsValid(def.maxForce) && def.maxForce >= 0.0)
        assert(b2IsValid(def.frequencyHz) && def.frequencyHz >= 0.0)
        assert(b2IsValid(def.dampingRatio) && def.dampingRatio >= 0.0)
        
        m_targetA = def.target
        
        m_maxForce = def.maxForce
        m_impulse = b2Vec2(0.0, 0.0)
        
        m_frequencyHz = def.frequencyHz
        m_dampingRatio = def.dampingRatio
        
        m_beta = 0.0
        m_gamma = 0.0
        super.init(def)
        m_localAnchorB = b2MulT(m_bodyB.transform, m_targetA)
    }
    
    override func initVelocityConstraints(_ data: inout b2SolverData) {
        m_indexB = m_bodyB.m_islandIndex
        m_localCenterB = m_bodyB.m_sweep.localCenter
        m_invMassB = m_bodyB.m_invMass
        m_invIB = m_bodyB.m_invI
        
        let cB = data.positions[m_indexB].c
        let aB = data.positions[m_indexB].a
        var vB = data.velocities[m_indexB].v
        var wB = data.velocities[m_indexB].w
        
        let qB = b2Rot(aB)
        
        let mass = m_bodyB.mass
        
        // Frequency
        let omega = 2.0 * b2_pi * m_frequencyHz
        
        // Damping coefficient
        let d = 2.0 * mass * m_dampingRatio * omega
        
        // Spring stiffness
        let k = mass * (omega * omega)
        
        // magic formulas
        // gamma has units of inverse mass.
        // beta has units of inverse time.
        let h = data.step.dt
        assert(d + h * k > b2_epsilon)
        m_gamma = h * (d + h * k)
        if m_gamma != 0.0 {
            m_gamma = 1.0 / m_gamma
        }
        m_beta = h * k * m_gamma
        
        // Compute the effective mass matrix.
        m_rB = b2Mul(qB, m_localAnchorB - m_localCenterB)
        
        // K    = [(1/m1 + 1/m2) * eye(2) - skew(r1) * invI1 * skew(r1) - skew(r2) * invI2 * skew(r2)]
        //      = [1/m1+1/m2     0    ] + invI1 * [r1.y*r1.y -r1.x*r1.y] + invI2 * [r1.y*r1.y -r1.x*r1.y]
        //        [    0     1/m1+1/m2]           [-r1.x*r1.y r1.x*r1.x]           [-r1.x*r1.y r1.x*r1.x]
        var K = b2Mat22()
        K.ex.x = m_invMassB + m_invIB * m_rB.y * m_rB.y + m_gamma
        K.ex.y = -m_invIB * m_rB.x * m_rB.y
        K.ey.x = K.ex.y
        K.ey.y = m_invMassB + m_invIB * m_rB.x * m_rB.x + m_gamma
        
        m_mass = K.getInverse()
        
        m_C = cB + m_rB - m_targetA
        m_C *= m_beta
        
        // Cheat with some damping
        wB *= 0.98
        
        if data.step.warmStarting {
            m_impulse *= data.step.dtRatio
            vB += m_invMassB * m_impulse
            wB += m_invIB * b2Cross(m_rB, m_impulse)
        }
        else {
            m_impulse.setZero()
        }
        
        data.velocities[m_indexB].v = vB
        data.velocities[m_indexB].w = wB
    }
    override func solveVelocityConstraints(_ data: inout b2SolverData) {
        var vB = data.velocities[m_indexB].v
        var wB = data.velocities[m_indexB].w
        
        // Cdot = v + cross(w, r)
        let Cdot = vB + b2Cross(wB, m_rB)
        var impulse = b2Mul(m_mass, -(Cdot + m_C + m_gamma * m_impulse))
        
        let oldImpulse = m_impulse
        m_impulse += impulse
        let maxImpulse = data.step.dt * m_maxForce
        if m_impulse.lengthSquared() > maxImpulse * maxImpulse {
            m_impulse *= maxImpulse / m_impulse.length()
        }
        impulse = m_impulse - oldImpulse
        
        vB += m_invMassB * impulse
        wB += m_invIB * b2Cross(m_rB, impulse)
        
        data.velocities[m_indexB].v = vB
        data.velocities[m_indexB].w = wB
    }
    override func solvePositionConstraints(_ data: inout b2SolverData) -> Bool {
        return true
    }
    
    // MARK: private variables
    var m_localAnchorB: b2Vec2!
    var m_targetA: b2Vec2
    var m_frequencyHz: b2Float
    var m_dampingRatio: b2Float
    var m_beta: b2Float
    
    // Solver shared
    var m_impulse: b2Vec2
    var m_maxForce: b2Float
    var m_gamma: b2Float
    
    // Solver temp
    var m_indexA: Int = 0
    var m_indexB: Int = 0
    var m_rB = b2Vec2()
    var m_localCenterB = b2Vec2()
    var m_invMassB: b2Float = 0.0
    var m_invIB: b2Float = 0.0
    var m_mass = b2Mat22()
    var m_C = b2Vec2()
}
