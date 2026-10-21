import AdaECS
import box2d
import Math

/// Live updates preserve native identity, wake connected bodies and persist the new settings.
@MainActor
extension PhysicsJoint2DComponent {
    func connectedJoint(of type: b2JointType) throws(PhysicsJoint2DError) -> RuntimeJoint2D {
        guard let record = runtimeJoint, record.isConnected, record.descriptor === jointDescriptor else { throw .notConnected }
        guard b2Joint_GetType(record.id) == type else { throw .unsupportedControl }
        return record
    }

    func tuningPair() throws(PhysicsJoint2DError) -> (Entity.ID, Entity.ID) {
        guard let (a, b) = RuntimeJoint2D.endpoints(jointDescriptor), let a else { throw .unsupportedControl }
        return (a, b)
    }

    mutating func install(_ joint: PhysicsJoint2DDescriptor.Joint, record: RuntimeJoint2D) {
        let descriptor = jointDescriptor.replacingJoint(joint)
        record.descriptor = descriptor
        jointDescriptor = descriptor
        b2Joint_WakeBodies(record.id)
    }

    func applyFrames(_ a: JointFrame2D, _ b: JointFrame2D, collide: Bool, to id: b2JointId) {
        b2Joint_SetLocalFrameA(id, a.native)
        b2Joint_SetLocalFrameB(id, b.native)
        b2Joint_SetCollideConnected(id, collide)
    }

    public mutating func updateSettings(_ settings: DistanceJoint2DSettings) throws(PhysicsJoint2DError) {
        try settings.validate()
        let record = try connectedJoint(of: b2_distanceJoint)
        let id = record.id
        let (a, b) = try tuningPair()
        applyFrames(settings.frameA, settings.frameB, collide: settings.collideConnected, to: id)
        b2DistanceJoint_SetRestLength(id, settings.length)
        b2DistanceJoint_EnableSpring(id, settings.spring != nil || settings.limits != nil || settings.motor != nil)
        b2DistanceJoint_SetSpringHertz(id, settings.spring?.hertz ?? 0)
        b2DistanceJoint_SetSpringDampingRatio(id, settings.spring?.dampingRatio ?? 1)
        b2DistanceJoint_SetLimits(id, settings.limits?.lower ?? settings.length, settings.limits?.upper ?? settings.length)
        b2DistanceJoint_EnableLimit(id, settings.limits != nil)
        b2DistanceJoint_SetTargetMotorSpeed(id, settings.motor?.speed ?? 0)
        b2DistanceJoint_SetMaxMotorForce(id, settings.motor?.maximumEffort ?? 0)
        b2DistanceJoint_EnableMotor(id, settings.motor != nil)
        install(.distance(a, b, settings), record: record)
    }

    public mutating func updateSettings(_ settings: RevoluteJoint2DSettings) throws(PhysicsJoint2DError) {
        try settings.validate()
        let record = try connectedJoint(of: b2_revoluteJoint)
        let id = record.id
        var settings = settings
        let updated: PhysicsJoint2DDescriptor.Joint
        switch jointDescriptor.joint {
        case let .hinge(a, b, _): updated = .hinge(a, b, settings)
        case let .worldHinge(b, anchor, _): updated = .worldHinge(b, anchor, settings)
        case let .revolute(b):
            let anchor = b2Body_GetWorldPoint(record.bodyA, b2Joint_GetLocalFrameA(id).p).asVector2
            updated = .worldHinge(b, anchor, settings)
        default: throw .unsupportedControl
        }
        if record.ownedAnchor != nil {
            // Keep a world hinge's original reference angle and pivot while retuning its forces.
            let a = b2Joint_GetLocalFrameA(id)
            let b = b2Joint_GetLocalFrameB(id)
            settings.frameA = JointFrame2D(position: a.p.asVector2, angle: b2Rot_GetAngle(a.q))
            settings.frameB = JointFrame2D(position: b.p.asVector2, angle: b2Rot_GetAngle(b.q))
        }
        applyFrames(settings.frameA, settings.frameB, collide: settings.collideConnected, to: id)
        b2RevoluteJoint_SetTargetAngle(id, settings.targetAngle)
        b2RevoluteJoint_EnableSpring(id, settings.spring != nil)
        b2RevoluteJoint_SetSpringHertz(id, settings.spring?.hertz ?? 0)
        b2RevoluteJoint_SetSpringDampingRatio(id, settings.spring?.dampingRatio ?? 1)
        b2RevoluteJoint_SetLimits(id, settings.limits?.lower ?? 0, settings.limits?.upper ?? 0)
        b2RevoluteJoint_EnableLimit(id, settings.limits != nil)
        b2RevoluteJoint_SetTargetMotorSpeed(id, settings.motor?.speed ?? 0)
        b2RevoluteJoint_SetMaxMotorTorque(id, settings.motor?.maximumEffort ?? 0)
        b2RevoluteJoint_EnableMotor(id, settings.motor != nil)
        install(updated, record: record)
    }

    public mutating func updateSettings(_ settings: PrismaticJoint2DSettings) throws(PhysicsJoint2DError) {
        try settings.validate()
        let record = try connectedJoint(of: b2_prismaticJoint)
        let id = record.id
        let (a, b) = try tuningPair()
        applyFrames(settings.frameA, settings.frameB, collide: settings.collideConnected, to: id)
        b2PrismaticJoint_SetTargetTranslation(id, settings.targetTranslation)
        b2PrismaticJoint_EnableSpring(id, settings.spring != nil)
        b2PrismaticJoint_SetSpringHertz(id, settings.spring?.hertz ?? 0)
        b2PrismaticJoint_SetSpringDampingRatio(id, settings.spring?.dampingRatio ?? 1)
        b2PrismaticJoint_SetLimits(id, settings.limits?.lower ?? 0, settings.limits?.upper ?? 0)
        b2PrismaticJoint_EnableLimit(id, settings.limits != nil)
        b2PrismaticJoint_SetTargetMotorSpeed(id, settings.motor?.speed ?? 0)
        b2PrismaticJoint_SetMaxMotorForce(id, settings.motor?.maximumEffort ?? 0)
        b2PrismaticJoint_EnableMotor(id, settings.motor != nil)
        install(.prismatic(a, b, settings), record: record)
    }

    public mutating func updateSettings(_ settings: WheelJoint2DSettings) throws(PhysicsJoint2DError) {
        try settings.validate()
        let record = try connectedJoint(of: b2_wheelJoint)
        let id = record.id
        let (a, b) = try tuningPair()
        applyFrames(settings.frameA, settings.frameB, collide: settings.collideConnected, to: id)
        b2WheelJoint_EnableSpring(id, settings.spring != nil)
        b2WheelJoint_SetSpringHertz(id, settings.spring?.hertz ?? 0)
        b2WheelJoint_SetSpringDampingRatio(id, settings.spring?.dampingRatio ?? 1)
        b2WheelJoint_SetLimits(id, settings.limits?.lower ?? 0, settings.limits?.upper ?? 0)
        b2WheelJoint_EnableLimit(id, settings.limits != nil)
        b2WheelJoint_SetTargetMotorSpeed(id, settings.motor?.speed ?? 0)
        b2WheelJoint_SetMaxMotorTorque(id, settings.motor?.maximumEffort ?? 0)
        b2WheelJoint_EnableMotor(id, settings.motor != nil)
        install(.wheel(a, b, settings), record: record)
    }

    public mutating func updateSettings(_ settings: WeldJoint2DSettings) throws(PhysicsJoint2DError) {
        try settings.validate()
        let record = try connectedJoint(of: b2_weldJoint)
        let id = record.id
        let (a, b) = try tuningPair()
        applyFrames(settings.frameA, settings.frameB, collide: settings.collideConnected, to: id)
        b2WeldJoint_SetLinearHertz(id, settings.linearSpring?.hertz ?? 0)
        b2WeldJoint_SetLinearDampingRatio(id, settings.linearSpring?.dampingRatio ?? 1)
        b2WeldJoint_SetAngularHertz(id, settings.angularSpring?.hertz ?? 0)
        b2WeldJoint_SetAngularDampingRatio(id, settings.angularSpring?.dampingRatio ?? 1)
        install(.weld(a, b, settings), record: record)
    }

    public mutating func updateSettings(_ settings: MotorJoint2DSettings) throws(PhysicsJoint2DError) {
        try settings.validate()
        let record = try connectedJoint(of: b2_motorJoint)
        let id = record.id
        let (a, b) = try tuningPair()
        applyFrames(settings.frameA, settings.frameB, collide: settings.collideConnected, to: id)
        b2MotorJoint_SetLinearVelocity(id, settings.linearVelocity.b2Vec)
        b2MotorJoint_SetAngularVelocity(id, settings.angularVelocity)
        b2MotorJoint_SetMaxVelocityForce(id, settings.maximumVelocityForce)
        b2MotorJoint_SetMaxVelocityTorque(id, settings.maximumVelocityTorque)
        b2MotorJoint_SetLinearHertz(id, settings.linearSpring?.hertz ?? 0)
        b2MotorJoint_SetLinearDampingRatio(id, settings.linearSpring?.dampingRatio ?? 1)
        b2MotorJoint_SetAngularHertz(id, settings.angularSpring?.hertz ?? 0)
        b2MotorJoint_SetAngularDampingRatio(id, settings.angularSpring?.dampingRatio ?? 1)
        b2MotorJoint_SetMaxSpringForce(id, settings.maximumSpringForce)
        b2MotorJoint_SetMaxSpringTorque(id, settings.maximumSpringTorque)
        install(.motor(a, b, settings), record: record)
    }
}
