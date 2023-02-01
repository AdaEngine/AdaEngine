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



/// Prismatic joint definition. This requires defining a line of
/// motion using an axis and an anchor point. The definition uses local
/// anchor points and a local axis so that the initial configuration
/// can violate the constraint slightly. The joint translation is zero
/// when the local anchor points coincide in world space. Using local
/// anchors and a local axis helps when saving and loading a game.
open class b2PrismaticJointDef : b2JointDef {
    public override init() {
        localAnchorA = b2Vec2()
        localAnchorB = b2Vec2()
        localAxisA = b2Vec2(1.0, 0.0)
        referenceAngle = 0.0
        enableLimit = false
        lowerTranslation = 0.0
        upperTranslation = 0.0
        enableMotor = false
        maxMotorForce = 0.0
        motorSpeed = 0.0
        super.init()
        type = b2JointType.prismaticJoint
    }
    
    /// Initialize the bodies, anchors, axis, and reference angle using the world
    /// anchor and unit world axis.
    public convenience init(bodyA: b2Body, bodyB: b2Body, anchor: b2Vec2, axis: b2Vec2) {
        self.init()
        initialize(bodyA: bodyA, bodyB: bodyB, anchor: anchor, axis: axis)
    }
    
    /// Initialize the bodies, anchors, axis, and reference angle using the world
    /// anchor and unit world axis.
    open func initialize(bodyA bA: b2Body, bodyB bB: b2Body, anchor: b2Vec2, axis: b2Vec2) {
        bodyA = bA
        bodyB = bB
        localAnchorA = bodyA.getLocalPoint(anchor)
        localAnchorB = bodyB.getLocalPoint(anchor)
        localAxisA = bodyA.getLocalVector(axis)
        referenceAngle = bodyB.angle - bodyA.angle
    }
    
    /// The local anchor point relative to bodyA's origin.
    open var localAnchorA: b2Vec2
    
    /// The local anchor point relative to bodyB's origin.
    open var localAnchorB: b2Vec2
    
    /// The local translation unit axis in bodyA.
    open var localAxisA: b2Vec2
    
    /// The constrained angle between the bodies: bodyB_angle - bodyA_angle.
    open var referenceAngle: b2Float
    
    /// Enable/disable the joint limit.
    open var enableLimit: Bool
    
    /// The lower translation limit, usually in meters.
    open var lowerTranslation: b2Float
    
    /// The upper translation limit, usually in meters.
    open var upperTranslation: b2Float
    
    /// Enable/disable the joint motor.
    open var enableMotor: Bool
    
    /// The maximum motor torque, usually in N-m.
    open var maxMotorForce: b2Float
    
    /// The desired motor speed in radians per second.
    open var motorSpeed: b2Float
}

// MARK: -
/// A prismatic joint. This joint provides one degree of freedom: translation
/// along an axis fixed in bodyA. Relative rotation is prevented. You can
/// use a joint limit to restrict the range of motion and a joint motor to
/// drive the motion or to model joint friction.
open class b2PrismaticJoint : b2Joint {
    open override var anchorA: b2Vec2 {
        return m_bodyA.getWorldPoint(m_localAnchorA)
    }
    open override var anchorB: b2Vec2 {
        return m_bodyB.getWorldPoint(m_localAnchorB)
    }
    
    open override func getReactionForce(inverseTimeStep inv_dt: b2Float) -> b2Vec2 {
        return inv_dt * (m_impulse.x * m_perp + (m_motorImpulse + m_impulse.z) * m_axis)
    }
    open override func getReactionTorque(inverseTimeStep inv_dt: b2Float) -> b2Float {
        return inv_dt * m_impulse.y
    }
    
    /// The local anchor point relative to bodyA's origin.
    open var localAnchorA: b2Vec2  { return m_localAnchorA }
    
    /// The local anchor point relative to bodyB's origin.
    open var localAnchorB: b2Vec2  { return m_localAnchorB }
    
    /// The local joint axis relative to bodyA.
    open var localAxisA: b2Vec2 { return m_localXAxisA }
    
    /// Get the reference angle.
    open var referenceAngle: b2Float { return m_referenceAngle }
    
    /// Get the current joint translation, usually in meters.
    open var jointTranslation: b2Float {
        let pA = m_bodyA.getWorldPoint(m_localAnchorA)
        let pB = m_bodyB.getWorldPoint(m_localAnchorB)
        let d = pB - pA
        let axis = m_bodyA.getWorldVector(m_localXAxisA)
        
        let translation = b2Dot(d, axis)
        return translation
    }
    
    /// Get the current joint translation speed, usually in meters per second.
    open var jointSpeed: b2Float {
        let bA = m_bodyA
        let bB = m_bodyB
        
        let rA = b2Mul(bA.m_xf.q, m_localAnchorA - bA.m_sweep.localCenter)
        let rB = b2Mul(bB.m_xf.q, m_localAnchorB - bB.m_sweep.localCenter)
        let p1 = bA.m_sweep.c + rA
        let p2 = bB.m_sweep.c + rB
        let d = p2 - p1
        let axis = b2Mul(bA.m_xf.q, m_localXAxisA)
        
        let vA = bA.m_linearVelocity
        let vB = bB.m_linearVelocity
        let wA = bA.m_angularVelocity
        let wB = bB.m_angularVelocity
        
        let speed = b2Dot(d, b2Cross(wA, axis)) + b2Dot(axis, vB + b2Cross(wB, rB) - vA - b2Cross(wA, rA))
        return speed
    }
    
    /// Is the joint limit enabled?
    open var isLimitEnabled: Bool {
        get {
            return m_enableLimit
        }
        set {
            enableLimit(newValue)
        }
    }
    
    /// Enable/disable the joint limit.
    open func enableLimit(_ flag: Bool) {
        if flag != m_enableLimit {
            m_bodyA.setAwake(true)
            m_bodyB.setAwake(true)
            m_enableLimit = flag
            m_impulse.z = 0.0
        }
    }
    
    /// Get the lower joint limit, usually in meters.
    open var lowerLimit: b2Float {
        return m_lowerTranslation
    }
    
    /// Get the upper joint limit, usually in meters.
    open var upperLimit: b2Float {
        return m_upperTranslation
    }
    
    /// Set the joint limits, usually in meters.
    open func setLimits(lower: b2Float, upper: b2Float) {
        assert(lower <= upper)
        if lower != m_lowerTranslation || upper != m_upperTranslation {
            m_bodyA.setAwake(true)
            m_bodyB.setAwake(true)
            m_lowerTranslation = lower
            m_upperTranslation = upper
            m_impulse.z = 0.0
        }
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
    
    /// Set the motor speed, usually in meters per second.
    func setMotorSpeed(_ speed: b2Float) {
        m_bodyA.setAwake(true)
        m_bodyB.setAwake(true)
        m_motorSpeed = speed
    }
    
    /// Get the motor speed, usually in meters per second.
    open var motorSpeed: b2Float {
        get {
            return m_motorSpeed
        }
        set {
            setMotorSpeed(newValue)
        }
    }
    
    /// Set the maximum motor force, usually in N.
    open func setMaxMotorForce(_ force: b2Float) {
        m_bodyA.setAwake(true)
        m_bodyB.setAwake(true)
        m_maxMotorForce = force
    }
    open var maxMotorForce: b2Float {
        get {
            return m_maxMotorForce
        }
        set {
            setMaxMotorForce(newValue)
        }
    }
    
    /// Get the current motor force given the inverse time step, usually in N.
    open func getMotorForce(inverseTimeStep inv_dt: b2Float) -> b2Float {
        return inv_dt * m_motorImpulse
    }
    
    /// Dump to println
    open override func dump() {
        let indexA = m_bodyA.m_islandIndex
        let indexB = m_bodyB.m_islandIndex
        
        print("  b2PrismaticJointDef jd;")
        print("  jd.bodyA = bodies[\(indexA)];")
        print("  jd.bodyB = bodies[\(indexB)];")
        print("  jd.collideConnected = bool(\(m_collideConnected));")
        print("  jd.localAnchorA.set(\(m_localAnchorA.x), \(m_localAnchorA.y));")
        print("  jd.localAnchorB.set(\(m_localAnchorB.x), \(m_localAnchorB.y)")
        print("  jd.localAxisA.set(\(m_localXAxisA.x), \(m_localXAxisA.y));")
        print("  jd.referenceAngle = \(m_referenceAngle);")
        print("  jd.enableLimit = bool(\(m_enableLimit));")
        print("  jd.lowerTranslation = \(m_lowerTranslation);")
        print("  jd.upperTranslation = \(m_upperTranslation);")
        print("  jd.enableMotor = bool(\(m_enableMotor));")
        print("  jd.motorSpeed = \(m_motorSpeed);")
        print("  jd.maxMotorForce = \(m_maxMotorForce);")
        print("  joints[\(m_index)] = m_world->createJoint(&jd);")
    }
    
    // MARK: private methods
    init(_ def: b2PrismaticJointDef) {
        m_localAnchorA = def.localAnchorA
        m_localAnchorB = def.localAnchorB
        m_localXAxisA = def.localAxisA
        m_localXAxisA.normalize()
        m_localYAxisA = b2Cross(1.0, m_localXAxisA)
        m_referenceAngle = def.referenceAngle
        
        m_impulse = b2Vec3(0.0, 0.0, 0.0)
        m_motorMass = 0.0
        m_motorImpulse = 0.0
        
        m_lowerTranslation = def.lowerTranslation
        m_upperTranslation = def.upperTranslation
        m_maxMotorForce = def.maxMotorForce
        m_motorSpeed = def.motorSpeed
        m_enableLimit = def.enableLimit
        m_enableMotor = def.enableMotor
        m_limitState = b2LimitState.inactiveLimit
        
        m_axis = b2Vec2(0.0, 0.0)
        m_perp = b2Vec2(0.0, 0.0)
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
        
        // Compute the effective masses.
        let rA = b2Mul(qA, m_localAnchorA - m_localCenterA)
        let rB = b2Mul(qB, m_localAnchorB - m_localCenterB)
        let d = (cB - cA) + rB - rA
        
        let mA = m_invMassA, mB = m_invMassB
        let iA = m_invIA, iB = m_invIB
        
        // Compute motor Jacobian and effective mass.
        b2Locally {
            self.m_axis = b2Mul(qA, self.m_localXAxisA)
            self.m_a1 = b2Cross(d + rA, self.m_axis)
            self.m_a2 = b2Cross(rB, self.m_axis)
            
            self.m_motorMass = mA + mB + iA * self.m_a1 * self.m_a1 + iB * self.m_a2 * self.m_a2
            if self.m_motorMass > 0.0 {
                self.m_motorMass = 1.0 / self.m_motorMass
            }
        }
        // Prismatic constraint.
        b2Locally {
            self.m_perp = b2Mul(qA, self.m_localYAxisA)
            
            self.m_s1 = b2Cross(d + rA, self.m_perp)
            self.m_s2 = b2Cross(rB, self.m_perp)
            
            let k11 = mA + mB + iA * self.m_s1 * self.m_s1 + iB * self.m_s2 * self.m_s2
            let k12 = iA * self.m_s1 + iB * self.m_s2
            let k13 = iA * self.m_s1 * self.m_a1 + iB * self.m_s2 * self.m_a2
            var k22 = iA + iB
            if k22 == 0.0 {
                // For bodies with fixed rotation.
                k22 = 1.0
            }
            let k23 = iA * self.m_a1 + iB * self.m_a2
            let k33 = mA + mB + iA * self.m_a1 * self.m_a1 + iB * self.m_a2 * self.m_a2
            
            self.m_K.ex.set(k11, k12, k13)
            self.m_K.ey.set(k12, k22, k23)
            self.m_K.ez.set(k13, k23, k33)
        }
        
        // Compute motor and limit terms.
        if m_enableLimit {
            let jointTranslation = b2Dot(m_axis, d)
            if abs(m_upperTranslation - m_lowerTranslation) < 2.0 * b2_linearSlop {
                m_limitState = b2LimitState.equalLimits
            }
            else if jointTranslation <= m_lowerTranslation {
                if m_limitState != b2LimitState.atLowerLimit {
                    m_limitState = b2LimitState.atLowerLimit
                    m_impulse.z = 0.0
                }
            }
            else if jointTranslation >= m_upperTranslation {
                if m_limitState != b2LimitState.atUpperLimit {
                    m_limitState = b2LimitState.atUpperLimit
                    m_impulse.z = 0.0
                }
            }
            else {
                m_limitState = b2LimitState.inactiveLimit
                m_impulse.z = 0.0
            }
        }
        else {
            m_limitState = b2LimitState.inactiveLimit
            m_impulse.z = 0.0
        }
        
        if m_enableMotor == false {
            m_motorImpulse = 0.0
        }
        
        if data.step.warmStarting {
            // Account for variable time step.
            m_impulse *= data.step.dtRatio
            m_motorImpulse *= data.step.dtRatio
            
            let P = m_impulse.x * m_perp + (m_motorImpulse + m_impulse.z) * m_axis
            let LA = m_impulse.x * m_s1 + m_impulse.y + (m_motorImpulse + m_impulse.z) * m_a1
            let LB = m_impulse.x * m_s2 + m_impulse.y + (m_motorImpulse + m_impulse.z) * m_a2
            
            vA -= mA * P
            wA -= iA * LA
            
            vB += mB * P
            wB += iB * LB
        }
        else {
            m_impulse.setZero()
            m_motorImpulse = 0.0
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
        
        // Solve linear motor constraint.
        if m_enableMotor && m_limitState != b2LimitState.equalLimits {
            let Cdot = b2Dot(m_axis, vB - vA) + m_a2 * wB - m_a1 * wA
            var impulse = m_motorMass * (m_motorSpeed - Cdot)
            let oldImpulse = m_motorImpulse
            let maxImpulse = data.step.dt * m_maxMotorForce
            m_motorImpulse = b2Clamp(m_motorImpulse + impulse, -maxImpulse, maxImpulse)
            impulse = m_motorImpulse - oldImpulse
            
            let P = impulse * m_axis
            let LA = impulse * m_a1
            let LB = impulse * m_a2
            
            vA -= mA * P
            wA -= iA * LA
            
            vB += mB * P
            wB += iB * LB
        }
        
        var Cdot1 = b2Vec2()
        Cdot1.x = b2Dot(m_perp, vB - vA) + m_s2 * wB - m_s1 * wA
        Cdot1.y = wB - wA
        
        if m_enableLimit && m_limitState != b2LimitState.inactiveLimit {
            // Solve prismatic and limit constraint in block form.
            let Cdot2 = b2Dot(m_axis, vB - vA) + m_a2 * wB - m_a1 * wA
            let Cdot = b2Vec3(Cdot1.x, Cdot1.y, Cdot2)
            
            let f1 = m_impulse
            var df =  m_K.solve33(-Cdot)
            m_impulse += df
            
            if m_limitState == b2LimitState.atLowerLimit {
                m_impulse.z = max(m_impulse.z, 0.0)
            }
            else if m_limitState == b2LimitState.atUpperLimit {
                m_impulse.z = min(m_impulse.z, 0.0)
            }
            
            // f2(1:2) = invK(1:2,1:2) * (-Cdot(1:2) - K(1:2,3) * (f2(3) - f1(3))) + f1(1:2)
            let b = -Cdot1 - (m_impulse.z - f1.z) * b2Vec2(m_K.ez.x, m_K.ez.y)
            let f2r = m_K.solve22(b) + b2Vec2(f1.x, f1.y)
            m_impulse.x = f2r.x
            m_impulse.y = f2r.y
            
            df = m_impulse - f1
            
            let P = df.x * m_perp + df.z * m_axis
            let LA = df.x * m_s1 + df.y + df.z * m_a1
            let LB = df.x * m_s2 + df.y + df.z * m_a2
            
            vA -= mA * P
            wA -= iA * LA
            
            vB += mB * P
            wB += iB * LB
        }
        else {
            // Limit is inactive, just solve the prismatic constraint in block form.
            let df = m_K.solve22(-Cdot1)
            m_impulse.x += df.x
            m_impulse.y += df.y
            
            let P = df.x * m_perp
            let LA = df.x * m_s1 + df.y
            let LB = df.x * m_s2 + df.y
            
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
        
        let mA = m_invMassA, mB = m_invMassB
        let iA = m_invIA, iB = m_invIB
        
        // Compute fresh Jacobians
        let rA = b2Mul(qA, m_localAnchorA - m_localCenterA)
        let rB = b2Mul(qB, m_localAnchorB - m_localCenterB)
        let d = cB + rB - cA - rA
        
        let axis = b2Mul(qA, m_localXAxisA)
        let a1 = b2Cross(d + rA, axis)
        let a2 = b2Cross(rB, axis)
        let perp = b2Mul(qA, m_localYAxisA)
        
        let s1 = b2Cross(d + rA, perp)
        let s2 = b2Cross(rB, perp)
        
        var impulse = b2Vec3()
        var C1 = b2Vec2()
        C1.x = b2Dot(perp, d)
        C1.y = aB - aA - m_referenceAngle
        
        var linearError = abs(C1.x)
        let angularError = abs(C1.y)
        
        var active = false
        var C2: b2Float = 0.0
        if m_enableLimit {
            let translation = b2Dot(axis, d)
            if abs(m_upperTranslation - m_lowerTranslation) < 2.0 * b2_linearSlop {
                // Prevent large angular corrections
                C2 = b2Clamp(translation, -b2_maxLinearCorrection, b2_maxLinearCorrection)
                linearError = max(linearError, abs(translation))
                active = true
            }
            else if translation <= m_lowerTranslation {
                // Prevent large linear corrections and allow some slop.
                C2 = b2Clamp(translation - m_lowerTranslation + b2_linearSlop, -b2_maxLinearCorrection, 0.0)
                linearError = max(linearError, m_lowerTranslation - translation)
                active = true
            }
            else if translation >= m_upperTranslation {
                // Prevent large linear corrections and allow some slop.
                C2 = b2Clamp(translation - m_upperTranslation - b2_linearSlop, 0.0, b2_maxLinearCorrection)
                linearError = max(linearError, translation - m_upperTranslation)
                active = true
            }
        }
        
        if active {
            let k11 = mA + mB + iA * s1 * s1 + iB * s2 * s2
            let k12 = iA * s1 + iB * s2
            let k13 = iA * s1 * a1 + iB * s2 * a2
            var k22 = iA + iB
            if k22 == 0.0 {
                // For fixed rotation
                k22 = 1.0
            }
            let k23 = iA * a1 + iB * a2
            let k33 = mA + mB + iA * a1 * a1 + iB * a2 * a2
            
            var K = b2Mat33()
            K.ex.set(k11, k12, k13)
            K.ey.set(k12, k22, k23)
            K.ez.set(k13, k23, k33)
            
            var C = b2Vec3()
            C.x = C1.x
            C.y = C1.y
            C.z = C2
            
            impulse = K.solve33(-C)
        }
        else {
            let k11 = mA + mB + iA * s1 * s1 + iB * s2 * s2
            let k12 = iA * s1 + iB * s2
            var k22 = iA + iB
            if k22 == 0.0 {
                k22 = 1.0
            }
            
            var K = b2Mat22()
            K.ex.set(k11, k12)
            K.ey.set(k12, k22)
            
            let impulse1 = K.solve(-C1)
            impulse.x = impulse1.x
            impulse.y = impulse1.y
            impulse.z = 0.0
        }
        
        let P = impulse.x * perp + impulse.z * axis
        let LA = impulse.x * s1 + impulse.y + impulse.z * a1
        let LB = impulse.x * s2 + impulse.y + impulse.z * a2
        
        cA -= mA * P
        aA -= iA * LA
        cB += mB * P
        aB += iB * LB
        
        data.positions[m_indexA].c = cA
        data.positions[m_indexA].a = aA
        data.positions[m_indexB].c = cB
        data.positions[m_indexB].a = aB
        
        return linearError <= b2_linearSlop && angularError <= b2_angularSlop
    }
    
    // MARK: private variables
    // Solver shared
    var m_localAnchorA: b2Vec2
    var m_localAnchorB: b2Vec2
    var m_localXAxisA: b2Vec2
    var m_localYAxisA: b2Vec2
    var m_referenceAngle: b2Float
    var m_impulse: b2Vec3
    var m_motorImpulse: b2Float
    var m_lowerTranslation: b2Float
    var m_upperTranslation: b2Float
    var m_maxMotorForce: b2Float
    var m_motorSpeed: b2Float
    var m_enableLimit: Bool
    var m_enableMotor: Bool
    var m_limitState: b2LimitState
    
    // Solver temp
    var m_indexA: Int = 0
    var m_indexB: Int = 0
    var m_localCenterA = b2Vec2()
    var m_localCenterB = b2Vec2()
    var m_invMassA: b2Float = 0.0
    var m_invMassB: b2Float = 0.0
    var m_invIA: b2Float = 0.0
    var m_invIB: b2Float = 0.0
    var m_axis = b2Vec2(), m_perp = b2Vec2()
    var m_s1: b2Float = 0.0, m_s2: b2Float = 0.0
    var m_a1: b2Float = 0.0, m_a2: b2Float = 0.0
    var m_K = b2Mat33()
    var m_motorMass: b2Float = 0.0
}
