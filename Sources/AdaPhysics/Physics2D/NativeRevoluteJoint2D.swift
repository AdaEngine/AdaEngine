import box2d
import Math

extension RuntimeJoint2D {
    static func createRevolute(_ descriptor: PhysicsJoint2DDescriptor, a: b2BodyId, b: b2BodyId, world: PhysicsWorld2D) throws(PhysicsJoint2DError) -> b2JointId {
        var settings: RevoluteJoint2DSettings
        let worldAnchor: Vector2?
        switch descriptor.joint {
        case let .hinge(_, _, value): settings = value; worldAnchor = nil
        case let .worldHinge(_, anchor, value): settings = value; worldAnchor = anchor
        case let .globalHinge(_, _, value): settings = value; worldAnchor = nil
        case .revolute: settings = .init(); worldAnchor = world.localPosition(b2Body_GetPosition(b))
        default: throw .invalidSettings
        }
        try settings.validate()
        if let worldAnchor {
            settings.frameA = JointFrame2D(position: worldAnchor, angle: b2Rot_GetAngle(b2Body_GetRotation(b)))
            settings.frameB = JointFrame2D(position: b2Body_GetLocalPoint(b, world.nativePosition(worldAnchor)).asVector2)
        }
        if case let .globalHinge(_, anchor, _) = descriptor.joint {
            guard anchor.isFinite else { throw .invalidSettings }
            let angle = b2Rot_GetAngle(b2Body_GetRotation(b))
            settings.frameA = JointFrame2D(angle: angle)
            settings.frameB = JointFrame2D(position: b2Body_GetLocalPoint(b, anchor.native).asVector2)
        }
        var definition = b2DefaultRevoluteJointDef()
        definition.base = connection(definition.base, a: a, b: b, frameA: settings.frameA, frameB: settings.frameB, collide: settings.collideConnected)
        definition.targetAngle = settings.targetAngle
        definition.enableSpring = settings.spring != nil
        definition.hertz = settings.spring?.hertz ?? 0
        definition.dampingRatio = settings.spring?.dampingRatio ?? 1
        definition.enableLimit = settings.limits != nil
        definition.lowerAngle = settings.limits?.lower ?? 0
        definition.upperAngle = settings.limits?.upper ?? 0
        definition.enableMotor = settings.motor != nil
        definition.motorSpeed = settings.motor?.speed ?? 0
        definition.maxMotorTorque = settings.motor?.maximumEffort ?? 0
        return unsafe b2CreateRevoluteJoint(world.worldId, &definition)
    }
}
