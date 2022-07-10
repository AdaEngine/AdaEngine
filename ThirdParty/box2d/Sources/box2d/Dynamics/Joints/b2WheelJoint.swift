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



/// Wheel joint definition. This requires defining a line of
/// motion using an axis and an anchor point. The definition uses local
/// anchor points and a local axis so that the initial configuration
/// can violate the constraint slightly. The joint translation is zero
/// when the local anchor points coincide in world space. Using local
/// anchors and a local axis helps when saving and loading a game.
open class b2WheelJointDef : b2JointDef {
    public override init() {
        localAnchorA = b2Vec2()
        localAnchorB = b2Vec2()
        localAxisA = b2Vec2(1.0, 0.0)
        enableMotor = false
        maxMotorTorque = 0.0
        motorSpeed = 0.0
        frequencyHz = 2.0
        dampingRatio = 0.7
        super.init()
        type = b2JointType.wheelJoint
    }
    
    /// Initialize the bodies, anchors, axis, and reference angle using the world
    /// anchor and world axis.
    public convenience init(bodyA: b2Body, bodyB: b2Body, anchor: b2Vec2, axis: b2Vec2) {
        self.init()
        initialize(bodyA: bodyA, bodyB: bodyB, anchor: anchor, axis: axis)
    }
    
    /// Initialize the bodies, anchors, axis, and reference angle using the world
    /// anchor and world axis.
    open func initialize(bodyA: b2Body, bodyB: b2Body, anchor: b2Vec2, axis: b2Vec2) {
        self.bodyA = bodyA
        self.bodyB = bodyB
        self.localAnchorA = bodyA.getLocalPoint(anchor)
        self.localAnchorB = bodyB.getLocalPoint(anchor)
        self.localAxisA = bodyA.getLocalVector(axis)
    }
    
    /// The local anchor point relative to bodyA's origin.
    open var localAnchorA: b2Vec2
    
    /// The local anchor point relative to bodyB's origin.
    open var localAnchorB: b2Vec2
    
    /// The local translation axis in bodyA.
    open var localAxisA: b2Vec2
    
    /// Enable/disable the joint motor.
    open var enableMotor: Bool
    
    /// The maximum motor torque, usually in N-m.
    open var maxMotorTorque: b2Float
    
    /// The desired motor speed in radians per second.
    open var motorSpeed: b2Float
    
    /// Suspension frequency, zero indicates no suspension
    open var frequencyHz: b2Float
    
    /// Suspension damping ratio, one indicates critical damping
    open var dampingRatio: b2Float
}

// MARK: -
/// A wheel joint. This joint provides two degrees of freedom: translation
/// along an axis fixed in bodyA and rotation in the plane. You can use a
/// joint limit to restrict the range of motion and a joint motor to drive
/// the rotation or to model rotational friction.
/// This joint is designed for vehicle suspensions.
open class b2WheelJoint : b2Joint {
    open override var anchorA: b2Vec2 {
        return m_bodyA.getWorldPoint(m_localAnchorA)
    }
    open override var anchorB: b2Vec2 {
        return m_bodyB.getWorldPoint(m_localAnchorB)
    }
    
    open override func getReactionForce(inverseTimeStep inv_dt: b2Float) -> b2Vec2 {
        return inv_dt * (m_impulse * m_ay + m_springImpulse * m_ax)
    }
    open override func getReactionTorque(inverseTimeStep inv_dt: b2Float) -> b2Float {
        return inv_dt * m_motorImpulse
    }
    
    /// The local anchor point relative to bodyA's origin.
    open var localAnchorA: b2Vec2  { return m_localAnchorA }
    
    /// The local anchor point relative to bodyB's origin.
    open var localAnchorB: b2Vec2  { return m_localAnchorB }
    
    /// The local joint axis relative to bodyA.
    open var localAxisA: b2Vec2 { return m_localXAxisA; }
    
    /// Get the current joint translation, usually in meters.
    open var jointTranslation: b2Float {
        let bA = m_bodyA
        let bB = m_bodyB
        
        let pA = bA.getWorldPoint(m_localAnchorA)
        let pB = bB.getWorldPoint(m_localAnchorB)
        let d = pB - pA
        let axis = bA.getWorldVector(m_localXAxisA)
        
        let translation = b2Dot(d, axis)
        return translation
    }
    
    /// Get the current joint translation speed, usually in meters per second.
    open var jointSpeed: b2Float {
        let wA = m_bodyA.m_angularVelocity
        let wB = m_bodyB.m_angularVelocity
        return wB - wA
    }
    
    /// Is the joint motor enabled?
    open var isMotorEnabled: Bool {
        get {
            return m_enableMotor
        }
        set {
            enableMotor(newValue)
        }
    }
    
    /// Enable/disable the joint motor.
    open func enableMotor(_ flag: Bool) {
        m_bodyA.setAwake(true)
        m_bodyB.setAwake(true)
        m_enableMotor = flag
    }
    
    /// Set the motor speed, usually in radians per second.
    open func setMotorSpeed(_ speed: b2Float) {
        m_bodyA.setAwake(true)
        m_bodyB.setAwake(true)
        m_motorSpeed = speed
    }
    
    /// Get the motor speed, usually in radians per second.
    open var motorSpeed: b2Float {
        get {
            return m_motorSpeed
        }
        set {
            setMotorSpeed(newValue)
        }
    }
    
    /// Set/Get the maximum motor force, usually in N-m.
    open func setMaxMotorTorque(_ torque: b2Float) {
        m_bodyA.setAwake(true)
        m_bodyB.setAwake(true)
        m_maxMotorTorque = torque
    }
    open var maxMotorTorque: b2Float {
        get {
            return m_maxMotorTorque
        }
        set {
            setMaxMotorTorque(newValue)
        }
    }
    
    /// Get the current motor torque given the inverse time step, usually in N-m.
    open func getMotorTorque(inverseTimeStamp inv_dt: b2Float) -> b2Float {
        return inv_dt * m_motorImpulse
    }
    
    /// Set/Get the spring frequency in hertz. Setting the frequency to zero disables the spring.
    open func setSpringFrequencyHz(_ hz: b2Float) {
        m_frequencyHz = hz
    }
    open var springFrequencyHz: b2Float {
        get {
            return m_frequencyHz
        }
        set {
            setSpringFrequencyHz(newValue)
        }
    }
    
    /// Set/Get the spring damping ratio
    open func setSpringDampingRatio(_ ratio: b2Float) {
        m_dampingRatio = ratio
    }
    open var springDampingRatio: b2Float {
        get {
            return m_dampingRatio
        }
        set {
            setSpringDampingRatio(newValue)
        }
    }
    
    /// Dump to println
    open override func dump() {
        let indexA = m_bodyA.m_islandIndex
        let indexB = m_bodyB.m_islandIndex
        
        print("  b2WheelJointDef jd;")
        print("  jd.bodyA = bodies[\(indexA)];")
        print("  jd.bodyB = bodies[\(indexB)];")
        print("  jd.collideConnected = bool(\(m_collideConnected));")
        print("  jd.localAnchorA.set(\(m_localAnchorA.x), \(m_localAnchorA.y));")
        print("  jd.localAnchorB.set(\(m_localAnchorB.x), \(m_localAnchorB.y));")
        print("  jd.localAxisA.set(\(m_localXAxisA.x), \(m_localXAxisA.y));")
        print("  jd.enableMotor = bool(\(m_enableMotor));")
        print("  jd.motorSpeed = \(m_motorSpeed);")
        print("  jd.maxMotorTorque = \(m_maxMotorTorque);")
        print("  jd.frequencyHz = \(m_frequencyHz);")
        print("  jd.dampingRatio = \(m_dampingRatio);")
        print("  joints[\(m_index)] = m_world->createJoint(&jd);")
    }
    
    // MARK: private methods
    
    init(_ def: b2WheelJointDef) {
        m_localAnchorA = def.localAnchorA
        m_localAnchorB = def.localAnchorB
        m_localXAxisA = def.localAxisA
        m_localYAxisA = b2Cross(1.0, m_localXAxisA)
        
        m_mass = 0.0
        m_impulse = 0.0
        m_motorMass = 0.0
        m_motorImpulse = 0.0
        m_springMass = 0.0
        m_springImpulse = 0.0
        
        m_maxMotorTorque = def.maxMotorTorque
        m_motorSpeed = def.motorSpeed
        m_enableMotor = def.enableMotor
        
        m_frequencyHz = def.frequencyHz
        m_dampingRatio = def.dampingRatio
        
        m_bias = 0.0
        m_gamma = 0.0
        
        m_ax = b2Vec2(0.0, 0.0)
        m_ay = b2Vec2(0.0, 0.0)
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
        
        let mA = m_invMassA, mB = m_invMassB
        let iA = m_invIA, iB = m_invIB
        
        let cA = data.positions[m_indexA].c
        let aA = data.positions[m_indexA].a
        var vA = data.velocities[m_indexA].v
        var wA = data.velocities[m_indexA].w
        
        let cB = data.positions[m_indexB].c
        let aB = data.positions[m_indexB].a
        var vB = data.velocities[m_indexB].v
        var wB = data.velocities[m_indexB].w
        
        let qA = b2Rot(aA), qB = b2Rot(aB)
        
        // Compute the effective masses.
        let rA = b2Mul(qA, m_localAnchorA - m_localCenterA)
        let rB = b2Mul(qB, m_localAnchorB - m_localCenterB)
        let d = cB + rB - cA - rA
        
        // Point to line constraint
        b2Locally {
            self.m_ay = b2Mul(qA, self.m_localYAxisA)
            self.m_sAy = b2Cross(d + rA, self.m_ay)
            self.m_sBy = b2Cross(rB, self.m_ay)
            
            self.m_mass = mA + mB + iA * self.m_sAy * self.m_sAy + iB * self.m_sBy * self.m_sBy
            
            if self.m_mass > 0.0 {
                self.m_mass = 1.0 / self.m_mass
            }
        }
        
        // Spring constraint
        m_springMass = 0.0
        m_bias = 0.0
        m_gamma = 0.0
        if m_frequencyHz > 0.0 {
            m_ax = b2Mul(qA, m_localXAxisA)
            m_sAx = b2Cross(d + rA, m_ax)
            m_sBx = b2Cross(rB, m_ax)
            
            let invMass = mA + mB + iA * m_sAx * m_sAx + iB * m_sBx * m_sBx
            
            if invMass > 0.0 {
                m_springMass = 1.0 / invMass
                
                let C = b2Dot(d, m_ax)
                
                // Frequency
                let omega = 2.0 * b2_pi * m_frequencyHz
                
                // Damping coefficient
                let d = 2.0 * m_springMass * m_dampingRatio * omega
                
                // Spring stiffness
                let k = m_springMass * omega * omega
                
                // magic formulas
                let h = data.step.dt
                m_gamma = h * (d + h * k)
                if m_gamma > 0.0 {
                    m_gamma = 1.0 / m_gamma
                }
                
                m_bias = C * h * k * m_gamma
                
                m_springMass = invMass + m_gamma
                if m_springMass > 0.0 {
                    m_springMass = 1.0 / m_springMass
                }
            }
        }
        else {
            m_springImpulse = 0.0
        }
        
        // Rotational motor
        if m_enableMotor {
            m_motorMass = iA + iB
            if m_motorMass > 0.0 {
                m_motorMass = 1.0 / m_motorMass
            }
        }
        else {
            m_motorMass = 0.0
            m_motorImpulse = 0.0
        }
        
        if data.step.warmStarting {
            // Account for variable time step.
            m_impulse *= data.step.dtRatio
            m_springImpulse *= data.step.dtRatio
            m_motorImpulse *= data.step.dtRatio
            
            let P = m_impulse * m_ay + m_springImpulse * m_ax
            let LA = m_impulse * m_sAy + m_springImpulse * m_sAx + m_motorImpulse
            let LB = m_impulse * m_sBy + m_springImpulse * m_sBx + m_motorImpulse
            
            vA -= m_invMassA * P
            wA -= m_invIA * LA
            
            vB += m_invMassB * P
            wB += m_invIB * LB
        }
        else {
            m_impulse = 0.0
            m_springImpulse = 0.0
            m_motorImpulse = 0.0
        }
        
        data.velocities[m_indexA].v = vA
        data.velocities[m_indexA].w = wA
        data.velocities[m_indexB].v = vB
        data.velocities[m_indexB].w = wB
    }
    override func solveVelocityConstraints(_ data: inout b2SolverData) {
        let mA = m_invMassA, mB = m_invMassB
        let iA = m_invIA, iB = m_invIB
        
        var vA = data.velocities[m_indexA].v
        var wA = data.velocities[m_indexA].w
        var vB = data.velocities[m_indexB].v
        var wB = data.velocities[m_indexB].w
        
        // Solve spring constraint
        b2Locally {
            let Cdot = b2Dot(self.m_ax, vB - vA) + self.m_sBx * wB - self.m_sAx * wA
            let impulse = -self.m_springMass * (Cdot + self.m_bias + self.m_gamma * self.m_springImpulse)
            self.m_springImpulse += impulse
            
            let P = impulse * self.m_ax
            let LA = impulse * self.m_sAx
            let LB = impulse * self.m_sBx
            
            vA -= mA * P
            wA -= iA * LA
            
            vB += mB * P
            wB += iB * LB
        }
        
        // Solve rotational motor constraint
        b2Locally {
            let Cdot = wB - wA - self.m_motorSpeed
            var impulse = -self.m_motorMass * Cdot
            
            let oldImpulse = self.m_motorImpulse
            let maxImpulse = data.step.dt * self.m_maxMotorTorque
            self.m_motorImpulse = b2Clamp(self.m_motorImpulse + impulse, -maxImpulse, maxImpulse)
            impulse = self.m_motorImpulse - oldImpulse
            
            wA -= iA * impulse
            wB += iB * impulse
        }
        
        // Solve point to line constraint
        b2Locally {
            let Cdot = b2Dot(self.m_ay, vB - vA) + self.m_sBy * wB - self.m_sAy * wA
            let impulse = -self.m_mass * Cdot
            self.m_impulse += impulse
            
            let P = impulse * self.m_ay
            let LA = impulse * self.m_sAy
            let LB = impulse * self.m_sBy
            
            vA -= mA * P
            wA -= iA * LA
            
            vB += mB * P
            wB += iB * LB
        }
        
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
        let d = (cB - cA) + rB - rA
        
        let ay = b2Mul(qA, m_localYAxisA)
        
        let sAy = b2Cross(d + rA, ay)
        let sBy = b2Cross(rB, ay)
        
        let C = b2Dot(d, ay)
        
        let k = m_invMassA + m_invMassB + m_invIA * m_sAy * m_sAy + m_invIB * m_sBy * m_sBy
        
        var impulse: b2Float
        if k != 0.0 {
            impulse = -C / k
        }
        else {
            impulse = 0.0
        }
        
        let P = impulse * ay
        let LA = impulse * sAy
        let LB = impulse * sBy
        
        cA -= m_invMassA * P
        aA -= m_invIA * LA
        cB += m_invMassB * P
        aB += m_invIB * LB
        
        data.positions[m_indexA].c = cA
        data.positions[m_indexA].a = aA
        data.positions[m_indexB].c = cB
        data.positions[m_indexB].a = aB
        
        return abs(C) <= b2_linearSlop
    }
    
    // MARK: private variables
    
    var m_frequencyHz: b2Float
    var m_dampingRatio: b2Float
    
    // Solver shared
    var m_localAnchorA: b2Vec2
    var m_localAnchorB: b2Vec2
    var m_localXAxisA: b2Vec2
    var m_localYAxisA: b2Vec2
    
    var m_impulse: b2Float
    var m_motorImpulse: b2Float
    var m_springImpulse: b2Float
    
    var m_maxMotorTorque: b2Float
    var m_motorSpeed: b2Float
    var m_enableMotor: Bool
    
    // Solver temp
    var m_indexA: Int = 0
    var m_indexB: Int = 0
    var m_localCenterA = b2Vec2()
    var m_localCenterB = b2Vec2()
    var m_invMassA: b2Float = 0.0
    var m_invMassB: b2Float = 0.0
    var m_invIA: b2Float = 0.0
    var m_invIB: b2Float = 0.0
    
    var m_ax = b2Vec2(), m_ay = b2Vec2()
    var m_sAx: b2Float = 0.0, m_sBx: b2Float = 0.0
    var m_sAy: b2Float = 0.0, m_sBy: b2Float = 0.0
    
    var m_mass: b2Float = 0.0
    var m_motorMass: b2Float = 0.0
    var m_springMass: b2Float = 0.0
    
    var m_bias: b2Float = 0.0
    var m_gamma: b2Float = 0.0
}
