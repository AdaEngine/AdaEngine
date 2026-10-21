import box2d

extension RuntimeJoint2D {
    static func createSlidingWeldFilter(_ descriptor: PhysicsJoint2DDescriptor, a: b2BodyId, b: b2BodyId, world: PhysicsWorld2D) throws(PhysicsJoint2DError) -> b2JointId {
        switch descriptor.joint {
        case let .prismatic(_, _, settings):
            try settings.validate()
            var definition = unsafe b2DefaultPrismaticJointDef()
            unsafe definition.base = connection(definition.base, a: a, b: b, frameA: settings.frameA, frameB: settings.frameB, collide: settings.collideConnected)
            unsafe definition.enableSpring = settings.spring != nil
            unsafe definition.hertz = settings.spring?.hertz ?? 0
            unsafe definition.dampingRatio = settings.spring?.dampingRatio ?? 1
            unsafe definition.targetTranslation = settings.targetTranslation
            unsafe definition.enableLimit = settings.limits != nil
            unsafe definition.lowerTranslation = settings.limits?.lower ?? 0
            unsafe definition.upperTranslation = settings.limits?.upper ?? 0
            unsafe definition.enableMotor = settings.motor != nil
            unsafe definition.motorSpeed = settings.motor?.speed ?? 0
            unsafe definition.maxMotorForce = settings.motor?.maximumEffort ?? 0
            return unsafe b2CreatePrismaticJoint(world.worldId, &definition)
        case let .weld(_, _, settings):
            try settings.validate()
            var definition = unsafe b2DefaultWeldJointDef()
            unsafe definition.base = connection(definition.base, a: a, b: b, frameA: settings.frameA, frameB: settings.frameB, collide: settings.collideConnected)
            unsafe definition.linearHertz = settings.linearSpring?.hertz ?? 0
            unsafe definition.linearDampingRatio = settings.linearSpring?.dampingRatio ?? 1
            unsafe definition.angularHertz = settings.angularSpring?.hertz ?? 0
            unsafe definition.angularDampingRatio = settings.angularSpring?.dampingRatio ?? 1
            return unsafe b2CreateWeldJoint(world.worldId, &definition)
        case .filter:
            var definition = unsafe b2DefaultFilterJointDef()
            unsafe definition.base.bodyIdA = a
            unsafe definition.base.bodyIdB = b
            return unsafe b2CreateFilterJoint(world.worldId, &definition)
        default: throw .invalidSettings
        }
    }
}
