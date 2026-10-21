import AdaECS
import Math

/// Controls relative velocity and optionally aligns two frames with bounded position/angle springs.
public struct MotorJoint2DSettings: Codable, Equatable, Sendable {
    public var frameA: JointFrame2D
    public var frameB: JointFrame2D
    public var linearVelocity: Vector2
    public var angularVelocity: Float
    public var maximumVelocityForce: Float
    public var maximumVelocityTorque: Float
    public var linearSpring: JointSpring2D?
    public var angularSpring: JointSpring2D?
    public var maximumSpringForce: Float
    public var maximumSpringTorque: Float
    public var collideConnected: Bool
    public init(
        frameA: JointFrame2D = .init(),
        frameB: JointFrame2D = .init(),
        linearVelocity: Vector2 = .zero,
        angularVelocity: Float = 0,
        maximumVelocityForce: Float = 1,
        maximumVelocityTorque: Float = 1,
        linearSpring: JointSpring2D? = nil,
        angularSpring: JointSpring2D? = nil,
        maximumSpringForce: Float = 100,
        maximumSpringTorque: Float = 100,
        collideConnected: Bool = false
    ) {
        self.frameA = frameA
        self.frameB = frameB
        self.linearVelocity = linearVelocity
        self.angularVelocity = angularVelocity
        self.maximumVelocityForce = maximumVelocityForce
        self.maximumVelocityTorque = maximumVelocityTorque
        self.linearSpring = linearSpring
        self.angularSpring = angularSpring
        self.maximumSpringForce = maximumSpringForce
        self.maximumSpringTorque = maximumSpringTorque
        self.collideConnected = collideConnected
    }
    func validate() throws(PhysicsJoint2DError) {
        guard frameA.isValid,
            frameB.isValid,
            linearVelocity.x.isFinite && linearVelocity.y.isFinite,
            angularVelocity.isFinite,
            linearSpring?.isValid != false,
            angularSpring?.isValid != false,
            maximumVelocityForce.isFinite && maximumVelocityForce >= 0,
            maximumVelocityTorque.isFinite && maximumVelocityTorque >= 0,
            maximumSpringForce.isFinite && maximumSpringForce >= 0,
            maximumSpringTorque.isFinite && maximumSpringTorque >= 0 else { throw .invalidSettings }
    }
}

extension PhysicsJoint2DDescriptor {
    @MainActor
    public static func motor(entityA: Entity, entityB: Entity, settings: MotorJoint2DSettings = .init()) throws(PhysicsJoint2DError) -> PhysicsJoint2DDescriptor {
        try validatePair(entityA, entityB)
        try settings.validate()
        return PhysicsJoint2DDescriptor(joint: .motor(entityA.id, entityB.id, settings))
    }
}
