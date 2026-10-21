import box2d
import Math

extension RuntimeJoint2D {
    static func createDistance(_ descriptor: PhysicsJoint2DDescriptor, a: b2BodyId, b: b2BodyId, world: PhysicsWorld2D) throws(PhysicsJoint2DError) -> b2JointId {
        let settings: DistanceJoint2DSettings
        switch descriptor.joint {
        case let .distance(_, _, value): settings = value
        case let .rope(_, _, anchorA, anchorB):
            let start = b2Body_GetWorldPoint(a, anchorA.b2Vec).asVector2
            let end = b2Body_GetWorldPoint(b, anchorB.b2Vec).asVector2
            let length = max((end - start).squaredLength.squareRoot(), 0.005 * b2GetLengthUnitsPerMeter())
            settings = DistanceJoint2DSettings(length: length, frameA: .init(position: anchorA), frameB: .init(position: anchorB), limits: .init(lower: 0, upper: length))
        default: throw PhysicsJoint2DError.invalidSettings
        }
        try settings.validate()
        var definition = b2DefaultDistanceJointDef()
        definition.base = connection(definition.base, a: a, b: b, frameA: settings.frameA, frameB: settings.frameB, collide: settings.collideConnected)
        definition.length = settings.length
        // Box2D requires enableSpring for limits/motors; zero hertz disables the spring force.
        definition.enableSpring = settings.spring != nil || settings.limits != nil || settings.motor != nil
        definition.hertz = settings.spring?.hertz ?? 0
        definition.dampingRatio = settings.spring?.dampingRatio ?? 1
        definition.enableLimit = settings.limits != nil
        definition.minLength = settings.limits?.lower ?? settings.length
        definition.maxLength = settings.limits?.upper ?? settings.length
        definition.enableMotor = settings.motor != nil
        definition.motorSpeed = settings.motor?.speed ?? 0
        definition.maxMotorForce = settings.motor?.maximumEffort ?? 0
        return unsafe b2CreateDistanceJoint(world.worldId, &definition)
    }
}
