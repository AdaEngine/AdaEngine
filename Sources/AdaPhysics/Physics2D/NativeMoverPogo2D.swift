import box2d
import Math

extension RuntimeJoint2D {
    static func createMoverPogo(_ descriptor: PhysicsJoint2DDescriptor, a: b2BodyId, b: b2BodyId, world: PhysicsWorld2D) throws(PhysicsJoint2DError) -> b2JointId {
        switch descriptor.joint {
        case let .mover(_, _, settings):
            try settings.validate()
            var definition = unsafe b2DefaultMoverJointDef()
            unsafe definition.base.bodyIdA = a
            unsafe definition.base.bodyIdB = b
            unsafe definition.base.collideConnected = settings.collideConnected
            unsafe definition.linearVelocity = settings.linearVelocity.b2Vec
            unsafe definition.maxVelocityForce = settings.maximumVelocityForce.b2Vec
            return unsafe b2CreateMoverJoint(world.worldId, &definition)
        case let .pogo(_, _, settings):
            try settings.validate()
            var definition = unsafe b2DefaultPogoJointDef()
            unsafe definition.base = connection(definition.base, a: a, b: b, frameA: settings.frameA, frameB: settings.frameB, collide: settings.collideConnected)
            unsafe definition.normal = (settings.normal / settings.normal.squaredLength.squareRoot()).b2Vec
            unsafe definition.restLength = settings.restLength
            unsafe definition.hertz = settings.spring.hertz
            unsafe definition.dampingRatio = settings.spring.dampingRatio
            unsafe definition.maxTensionForce = settings.maximumTensionForce
            unsafe definition.maxCompressionForce = settings.maximumCompressionForce
            unsafe definition.impulse = settings.initialImpulse
            unsafe definition.velocity = settings.initialVelocity
            return unsafe b2CreatePogoJoint(world.worldId, &definition)
        default: throw .invalidSettings
        }
    }
}

@MainActor
extension PhysicsJoint2DComponent {
    public mutating func updateSettings(_ settings: MoverJoint2DSettings) throws(PhysicsJoint2DError) {
        try settings.validate()
        let record = try connectedJoint(of: b2_moverJoint)
        let (a, b) = try tuningPair()
        b2MoverJoint_SetLinearVelocity(record.id, settings.linearVelocity.b2Vec)
        b2MoverJoint_SetMaxVelocityForce(record.id, settings.maximumVelocityForce.b2Vec)
        b2Joint_SetCollideConnected(record.id, settings.collideConnected)
        install(.mover(a, b, settings), record: record)
    }

    /// Pogo normal/force bounds require descriptor replacement; native live setters cover spring/length only.
    public mutating func updatePogoSpring(_ spring: JointSpring2D, restLength: Float) throws(PhysicsJoint2DError) {
        let record = try connectedJoint(of: b2_pogoJoint)
        guard case let .pogo(a, b, previous) = jointDescriptor.joint else { throw .unsupportedControl }
        var settings = previous
        settings.spring = spring
        settings.restLength = restLength
        try settings.validate()
        b2PogoJoint_SetRestLength(record.id, restLength)
        b2PogoJoint_SetSpringHertz(record.id, spring.hertz)
        b2PogoJoint_SetSpringDampingRatio(record.id, spring.dampingRatio)
        install(.pogo(a, b, settings), record: record)
    }
}
