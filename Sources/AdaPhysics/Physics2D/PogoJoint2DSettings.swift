import AdaECS
import Math

/// Experimental pogo: spring length follows frame B's local Y; the world normal sets force direction.
public struct PogoJoint2DSettings: Codable, Equatable, Sendable {
    public var frameA: JointFrame2D
    public var frameB: JointFrame2D
    public var normal: Vector2
    public var restLength: Float
    public var spring: JointSpring2D
    public var maximumTensionForce: Float
    public var maximumCompressionForce: Float
    public var initialImpulse: Float
    public var initialVelocity: Float
    public var collideConnected: Bool
    public init(
        frameA: JointFrame2D = .init(),
        frameB: JointFrame2D = .init(),
        normal: Vector2 = [0, 1],
        restLength: Float = 1,
        spring: JointSpring2D = .init(hertz: 4),
        maximumTensionForce: Float = 0,
        maximumCompressionForce: Float = 1000,
        initialImpulse: Float = 0,
        initialVelocity: Float = 0,
        collideConnected: Bool = true
    ) {
        self.frameA = frameA
        self.frameB = frameB
        self.normal = normal
        self.restLength = restLength
        self.spring = spring
        self.maximumTensionForce = maximumTensionForce
        self.maximumCompressionForce = maximumCompressionForce
        self.initialImpulse = initialImpulse
        self.initialVelocity = initialVelocity
        self.collideConnected = collideConnected
    }
    func validate() throws(PhysicsJoint2DError) {
        guard frameA.isValid && frameB.isValid,
            normal.x.isFinite && normal.y.isFinite && normal.squaredLength.isFinite && normal.squaredLength > Float.ulpOfOne,
            restLength.isFinite && restLength >= 0,
            spring.isValid,
            maximumTensionForce.isFinite && maximumTensionForce >= 0,
            maximumCompressionForce.isFinite && maximumCompressionForce >= 0,
            initialImpulse.isFinite && initialVelocity.isFinite else { throw .invalidSettings }
    }
}

extension PhysicsJoint2DDescriptor {
    @MainActor
    public static func pogo(entityA: Entity, entityB: Entity, settings: PogoJoint2DSettings = .init()) throws(PhysicsJoint2DError) -> PhysicsJoint2DDescriptor {
        try validatePair(entityA, entityB)
        try settings.validate()
        return PhysicsJoint2DDescriptor(joint: .pogo(entityA.id, entityB.id, settings))
    }
}
