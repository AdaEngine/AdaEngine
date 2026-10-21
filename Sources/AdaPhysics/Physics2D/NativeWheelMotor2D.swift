import box2d
import Math

extension RuntimeJoint2D {
    static func createWheelMotor(_ descriptor: PhysicsJoint2DDescriptor, a: b2BodyId, b: b2BodyId, world: PhysicsWorld2D) throws(PhysicsJoint2DError) -> b2JointId {
        switch descriptor.joint {
        case let .wheel(_, _, settings):
            try settings.validate()
            var definition = unsafe b2DefaultWheelJointDef()
            unsafe definition.base = connection(definition.base, a: a, b: b, frameA: settings.frameA, frameB: settings.frameB, collide: settings.collideConnected)
            unsafe definition.enableSpring = settings.spring != nil
            unsafe definition.hertz = settings.spring?.hertz ?? 0
            unsafe definition.dampingRatio = settings.spring?.dampingRatio ?? 1
            unsafe definition.enableLimit = settings.limits != nil
            unsafe definition.lowerTranslation = settings.limits?.lower ?? 0
            unsafe definition.upperTranslation = settings.limits?.upper ?? 0
            unsafe definition.enableMotor = settings.motor != nil
            unsafe definition.motorSpeed = settings.motor?.speed ?? 0
            unsafe definition.maxMotorTorque = settings.motor?.maximumEffort ?? 0
            return unsafe b2CreateWheelJoint(world.worldId, &definition)
        case let .motor(_, _, settings):
            try settings.validate()
            var definition = unsafe b2DefaultMotorJointDef()
            unsafe definition.base = connection(definition.base, a: a, b: b, frameA: settings.frameA, frameB: settings.frameB, collide: settings.collideConnected)
            unsafe definition.linearVelocity = settings.linearVelocity.b2Vec
            unsafe definition.angularVelocity = settings.angularVelocity
            unsafe definition.maxVelocityForce = settings.maximumVelocityForce
            unsafe definition.maxVelocityTorque = settings.maximumVelocityTorque
            unsafe definition.linearHertz = settings.linearSpring?.hertz ?? 0
            unsafe definition.linearDampingRatio = settings.linearSpring?.dampingRatio ?? 1
            unsafe definition.angularHertz = settings.angularSpring?.hertz ?? 0
            unsafe definition.angularDampingRatio = settings.angularSpring?.dampingRatio ?? 1
            unsafe definition.maxSpringForce = settings.maximumSpringForce
            unsafe definition.maxSpringTorque = settings.maximumSpringTorque
            return unsafe b2CreateMotorJoint(world.worldId, &definition)
        default: throw .invalidSettings
        }
    }
}
