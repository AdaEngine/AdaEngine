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



/// Revolute joint definition. This requires defining an
/// anchor point where the bodies are joined. The definition
/// uses local anchor points so that the initial configuration
/// can violate the constraint slightly. You also need to
/// specify the initial relative angle for joint limits. This
/// helps when saving and loading a game.
/// The local anchor points are measured from the body's origin
/// rather than the center of mass because:
/// 1. you might not know where the center of mass will be.
/// 2. if you add/remove shapes from a body and recompute the mass,
///    the joints will be broken.
open class b2RevoluteJointDef : b2JointDef {
    public override init() {
        localAnchorA = b2Vec2(0.0, 0.0)
        localAnchorB = b2Vec2(0.0, 0.0)
        referenceAngle = 0.0
        lowerAngle = 0.0
        upperAngle = 0.0
        maxMotorTorque = 0.0
        motorSpeed = 0.0
        enableLimit = false
        enableMotor = false
        super.init()
        type = b2JointType.revoluteJoint
    }
    
    /// Initialize the bodies, anchors, and reference angle using a world
    /// anchor point.
    public convenience init(bodyA: b2Body, bodyB: b2Body, anchor: b2Vec2) {
        self.init()
        initialize(bodyA, bodyB:bodyB, anchor: anchor)
    }
    
    /// Initialize the bodies, anchors, and reference angle using a world
    /// anchor point.
    open func initialize(_ bodyA: b2Body, bodyB: b2Body, anchor: b2Vec2) {
        self.bodyA = bodyA
        self.bodyB = bodyB
        self.localAnchorA = bodyA.getLocalPoint(anchor)
        self.localAnchorB = bodyB.getLocalPoint(anchor)
        self.referenceAngle = bodyB.angle - bodyA.angle
    }
    
    /// The local anchor point relative to bodyA's origin.
    open var localAnchorA: b2Vec2
    
    /// The local anchor point relative to bodyB's origin.
    open var localAnchorB: b2Vec2
    
    /// The bodyB angle minus bodyA angle in the reference state (radians).
    open var referenceAngle: b2Float
    
    /// A flag to enable joint limits.
    open var enableLimit: Bool
    
    /// The lower angle for the joint limit (radians).
    open var lowerAngle: b2Float
    
    /// The upper angle for the joint limit (radians).
    open var upperAngle: b2Float
    
    /// A flag to enable the joint motor.
    open var enableMotor: Bool
    
    /// The desired motor speed. Usually in radians per second.
    open var motorSpeed: b2Float
    
    /// The maximum motor torque used to achieve the desired motor speed.
    /// Usually in N-m.
    open var maxMotorTorque: b2Float
}

// MARK: -
/// A revolute joint constrains two bodies to share a common point while they
/// are free to rotate about the point. The relative rotation about the shared
/// point is the joint angle. You can limit the relative rotation with
/// a joint limit that specifies a lower and upper angle. You can use a motor
/// to drive the relative rotation about the shared point. A maximum motor torque
/// is provided so that infinite forces are not generated.
open class b2RevoluteJoint : b2Joint {
    open override var anchorA: b2Vec2 {
        return m_bodyA.getWorldPoint(m_localAnchorA)
    }
    open override var anchorB: b2Vec2 {
        return m_bodyB.getWorldPoint(m_localAnchorB)
    }
    
    /// The local anchor point relative to bodyA's origin.
    open var localAnchorA: b2Vec2  { return m_localAnchorA }
    
    /// The local anchor point relative to bodyB's origin.
    open var localAnchorB: b2Vec2  { return m_localAnchorB }
    
    /// Get the reference angle.
    open var referenceAngle: b2Float { return m_referenceAngle }
    
    /// Get the current joint angle in radians.
    open var jointAngle: b2Float {
        let bA = m_bodyA
        let bB = m_bodyB
        return bB.m_sweep.a - bA.m_sweep.a - m_referenceAngle
    }
    
    /// Get the current joint angle speed in radians per second.
    open var jointSpeed: b2Float {
        let bA = m_bodyA
        let bB = m_bodyB
        return bB.m_angularVelocity - bA.m_angularVelocity
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
    
    /// Get the lower joint limit in radians.
    open var lowerLimit: b2Float {
        return m_lowerAngle
    }
    
    /// Get the upper joint limit in radians.
    open var upperLimit: b2Float {
        return m_upperAngle
    }
    
    /// Set the joint limits in radians.
    open func setLimits(lower: b2Float, upper: b2Float) {
        assert(lower <= upper)
        
        if lower != m_lowerAngle || upper != m_upperAngle {
            m_bodyA.setAwake(true)
            m_bodyB.setAwake(true)
            m_impulse.z = 0.0
            m_lowerAngle = lower
            m_upperAngle = upper
        }
    }
    
    /// Is the joint motor enabled?
    open var isMotorEnabled: Bool {
        return m_enableMotor
    }
    
    /// Enable/disable the joint motor.
    open func enableMotor(_ flag: Bool) {
        m_bodyA.setAwake(true)
        m_bodyB.setAwake(true)
        m_enableMotor = flag
    }
    
    /// Set the motor speed in radians per second.
    open func setMotorSpeed(_ speed: b2Float) {
        m_bodyA.setAwake(true)
        m_bodyB.setAwake(true)
        m_motorSpeed = speed
    }
    
    /// Get the motor speed in radians per second.
    open var motorSpeed: b2Float {
        get {
            return m_motorSpeed
        }
        set {
            setMotorSpeed(newValue)
        }
    }
    
    /// Set the maximum motor torque, usually in N-m.
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
    
    /// Get the reaction force given the inverse time step.
    /// Unit is N.
    open override func getReactionForce(inverseTimeStep inv_dt: b2Float) -> b2Vec2 {
        let P = b2Vec2(m_impulse.x, m_impulse.y)
        return inv_dt * P
    }
    
    /// Get the reaction torque due to the joint limit given the inverse time step.
    /// Unit is N*m.
    open override func getReactionTorque(inverseTimeStep inv_dt: b2Float) -> b2Float {
        return inv_dt * m_impulse.z
    }
    
    /// Get the current motor torque given the inverse time step.
    /// Unit is N*m.
    open func getMotorTorque(_ inv_dt: b2Float) -> b2Float {
        return inv_dt * m_motorImpulse
    }
    
    /// Dump to println.
    open override func dump() {
        let indexA = m_bodyA.m_islandIndex
        let indexB = m_bodyB.m_islandIndex
        
        print("  b2RevoluteJointDef jd;")
        print("  jd.bodyA = bodies[\(indexA)];")
        print("  jd.bodyB = bodies[\(indexB)];")
        print("  jd.collideConnected = bool(\(m_collideConnected));")
        print("  jd.localAnchorA.set(\(m_localAnchorA.x), \(m_localAnchorA.y));")
        print("  jd.localAnchorB.set(\(m_localAnchorB.x), \(m_localAnchorB.y));")
        print("  jd.referenceAngle = \(m_referenceAngle);")
        print("  jd.enableLimit = bool(\(m_enableLimit));")
        print("  jd.lowerAngle = \(m_lowerAngle);")
        print("  jd.upperAngle = \(m_upperAngle);")
        print("  jd.enableMotor = bool(\(m_enableMotor));")
        print("  jd.motorSpeed = \(m_motorSpeed);")
        print("  jd.maxMotorTorque = \(m_maxMotorTorque);")
        print("  joints[\(m_index)] = m_world->createJoint(&jd);")
    }
    
    // MARK: private methods
    
    init(_ def: b2RevoluteJointDef) {
        m_localAnchorA = def.localAnchorA
        m_localAnchorB = def.localAnchorB
        m_referenceAngle = def.referenceAngle
        
        m_impulse = b2Vec3(0.0, 0.0, 0.0)
        m_motorImpulse = 0.0
        
        m_lowerAngle = def.lowerAngle
        m_upperAngle = def.upperAngle
        m_maxMotorTorque = def.maxMotorTorque
        m_motorSpeed = def.motorSpeed
        m_enableLimit = def.enableLimit
        m_enableMotor = def.enableMotor
        m_limitState = b2LimitState.inactiveLimit
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
        
        let fixedRotation = (iA + iB == 0.0)
        
        m_mass.ex.x = mA + mB + m_rA.y * m_rA.y * iA + m_rB.y * m_rB.y * iB
        m_mass.ey.x = -m_rA.y * m_rA.x * iA - m_rB.y * m_rB.x * iB
        m_mass.ez.x = -m_rA.y * iA - m_rB.y * iB
        m_mass.ex.y = m_mass.ey.x
        m_mass.ey.y = mA + mB + m_rA.x * m_rA.x * iA + m_rB.x * m_rB.x * iB
        m_mass.ez.y = m_rA.x * iA + m_rB.x * iB
        m_mass.ex.z = m_mass.ez.x
        m_mass.ey.z = m_mass.ez.y
        m_mass.ez.z = iA + iB
        
        m_motorMass = iA + iB
        if m_motorMass > 0.0 {
            m_motorMass = 1.0 / m_motorMass
        }
        
        if m_enableMotor == false || fixedRotation {
            m_motorImpulse = 0.0
        }
        
        if m_enableLimit && fixedRotation == false {
            let jointAngle = aB - aA - m_referenceAngle
            if abs(m_upperAngle - m_lowerAngle) < 2.0 * b2_angularSlop {
                m_limitState = b2LimitState.equalLimits
            }
            else if jointAngle <= m_lowerAngle {
                if m_limitState != b2LimitState.atLowerLimit {
                    m_impulse.z = 0.0
                }
                m_limitState = b2LimitState.atLowerLimit
            }
            else if jointAngle >= m_upperAngle {
                if m_limitState != b2LimitState.atUpperLimit {
                    m_impulse.z = 0.0
                }
                m_limitState = b2LimitState.atUpperLimit
            }
            else {
                m_limitState = b2LimitState.inactiveLimit
                m_impulse.z = 0.0
            }
        }
        else {
            m_limitState = b2LimitState.inactiveLimit
        }
        
        if data.step.warmStarting {
            // Scale impulses to support a variable time step.
            m_impulse *= data.step.dtRatio
            m_motorImpulse *= data.step.dtRatio
            
            let P = b2Vec2(m_impulse.x, m_impulse.y)
            
            vA -= mA * P
            wA -= iA * (b2Cross(m_rA, P) + m_motorImpulse + m_impulse.z)
            
            vB += mB * P
            wB += iB * (b2Cross(m_rB, P) + m_motorImpulse + m_impulse.z)
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
        
        let fixedRotation = (iA + iB == 0.0)
        
        // Solve motor constraint.
        if m_enableMotor && m_limitState != b2LimitState.equalLimits && fixedRotation == false {
            let Cdot = wB - wA - m_motorSpeed
            var impulse = -m_motorMass * Cdot
            let oldImpulse = m_motorImpulse
            let maxImpulse = data.step.dt * m_maxMotorTorque
            m_motorImpulse = b2Clamp(m_motorImpulse + impulse, -maxImpulse, maxImpulse)
            impulse = m_motorImpulse - oldImpulse
            
            wA -= iA * impulse
            wB += iB * impulse
        }
        
        // Solve limit constraint.
        if m_enableLimit && m_limitState != b2LimitState.inactiveLimit && fixedRotation == false {
            let Cdot1 = vB + b2Cross(wB, m_rB) - vA - b2Cross(wA, m_rA)
            let Cdot2 = wB - wA
            let Cdot = b2Vec3(Cdot1.x, Cdot1.y, Cdot2)
            
            var impulse = -m_mass.solve33(Cdot)
            
            if m_limitState == b2LimitState.equalLimits {
                m_impulse += impulse
            }
            else if m_limitState == b2LimitState.atLowerLimit {
                let newImpulse = m_impulse.z + impulse.z
                if newImpulse < 0.0 {
                    let rhs = -Cdot1 + m_impulse.z * b2Vec2(m_mass.ez.x, m_mass.ez.y)
                    let reduced = m_mass.solve22(rhs)
                    impulse.x = reduced.x
                    impulse.y = reduced.y
                    impulse.z = -m_impulse.z
                    m_impulse.x += reduced.x
                    m_impulse.y += reduced.y
                    m_impulse.z = 0.0
                }
                else {
                    m_impulse += impulse
                }
            }
            else if m_limitState == b2LimitState.atUpperLimit {
                let newImpulse = m_impulse.z + impulse.z
                if newImpulse > 0.0 {
                    let rhs = -Cdot1 + m_impulse.z * b2Vec2(m_mass.ez.x, m_mass.ez.y)
                    let reduced = m_mass.solve22(rhs)
                    impulse.x = reduced.x
                    impulse.y = reduced.y
                    impulse.z = -m_impulse.z
                    m_impulse.x += reduced.x
                    m_impulse.y += reduced.y
                    m_impulse.z = 0.0
                }
                else {
                    m_impulse += impulse
                }
            }
            
            let P = b2Vec2(impulse.x, impulse.y)
            
            vA -= mA * P
            wA -= iA * (b2Cross(m_rA, P) + impulse.z)
            
            vB += mB * P
            wB += iB * (b2Cross(m_rB, P) + impulse.z)
        }
        else {
            // Solve point-to-point constraint
            let Cdot = vB + b2Cross(wB, m_rB) - vA - b2Cross(wA, m_rA)
            let impulse = m_mass.solve22(-Cdot)
            
            m_impulse.x += impulse.x
            m_impulse.y += impulse.y
            
            vA -= mA * impulse
            wA -= iA * b2Cross(m_rA, impulse)
            
            vB += mB * impulse
            wB += iB * b2Cross(m_rB, impulse)
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
        
        var qA = b2Rot(aA), qB = b2Rot(aB)
        
        var angularError: b2Float = 0.0
        var positionError: b2Float = 0.0
        
        let fixedRotation = (m_invIA + m_invIB == 0.0)
        
        // Solve angular limit constraint.
        if m_enableLimit && m_limitState != b2LimitState.inactiveLimit && fixedRotation == false {
            let angle = aB - aA - m_referenceAngle
            var limitImpulse: b2Float = 0.0
            
            if m_limitState == b2LimitState.equalLimits {
                // Prevent large angular corrections
                let C = b2Clamp(angle - m_lowerAngle, -b2_maxAngularCorrection, b2_maxAngularCorrection)
                limitImpulse = -m_motorMass * C
                angularError = abs(C)
            }
            else if m_limitState == b2LimitState.atLowerLimit {
                var C = angle - m_lowerAngle
                angularError = -C
                
                // Prevent large angular corrections and allow some slop.
                C = b2Clamp(C + b2_angularSlop, -b2_maxAngularCorrection, 0.0)
                limitImpulse = -m_motorMass * C
            }
            else if m_limitState == b2LimitState.atUpperLimit {
                var C = angle - m_upperAngle
                angularError = C
                
                // Prevent large angular corrections and allow some slop.
                C = b2Clamp(C - b2_angularSlop, 0.0, b2_maxAngularCorrection)
                limitImpulse = -m_motorMass * C
            }
            
            aA -= m_invIA * limitImpulse
            aB += m_invIB * limitImpulse
        }
        
        // Solve point-to-point constraint.
        b2Locally {
            qA.set(aA)
            qB.set(aB)
            let rA = b2Mul(qA, self.m_localAnchorA - self.m_localCenterA)
            let rB = b2Mul(qB, self.m_localAnchorB - self.m_localCenterB)
            
            let C = cB + rB - cA - rA
            positionError = C.length()
            
            let mA = self.m_invMassA, mB = self.m_invMassB
            let iA = self.m_invIA, iB = self.m_invIB
            
            var K = b2Mat22()
            K.ex.x = mA + mB + iA * rA.y * rA.y + iB * rB.y * rB.y
            K.ex.y = -iA * rA.x * rA.y - iB * rB.x * rB.y
            K.ey.x = K.ex.y
            K.ey.y = mA + mB + iA * rA.x * rA.x + iB * rB.x * rB.x
            
            let impulse = -K.solve(C)
            
            cA -= mA * impulse
            aA -= iA * b2Cross(rA, impulse)
            
            cB += mB * impulse
            aB += iB * b2Cross(rB, impulse)
        }
        
        data.positions[m_indexA].c = cA
        data.positions[m_indexA].a = aA
        data.positions[m_indexB].c = cB
        data.positions[m_indexB].a = aB
        
        return positionError <= b2_linearSlop && angularError <= b2_angularSlop
    }
    
    // MARK: private variables
    
    // Solver shared
    var m_localAnchorA: b2Vec2
    var m_localAnchorB: b2Vec2
    var m_impulse: b2Vec3
    var m_motorImpulse: b2Float
    
    var m_enableMotor: Bool
    var m_maxMotorTorque: b2Float
    var m_motorSpeed: b2Float
    
    var m_enableLimit: Bool
    var m_referenceAngle: b2Float
    var m_lowerAngle: b2Float
    var m_upperAngle: b2Float
    
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
    var m_mass = b2Mat33()		     // effective mass for point-to-point constraint.
    var m_motorMass: b2Float = 0.0 // effective mass for motor/limit angular constraint.
    var m_limitState = b2LimitState.inactiveLimit
}

