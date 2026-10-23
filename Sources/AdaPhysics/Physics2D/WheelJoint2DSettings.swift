import AdaECS

/// Suspension follows local frame A's X axis; the wheel rotates freely. Motor effort is torque.
public struct WheelJoint2DSettings: Codable, Equatable, Sendable {
    public var frameA: JointFrame2D
    public var frameB: JointFrame2D
    public var spring: JointSpring2D?
    public var limits: JointLimits2D?
    public var motor: JointMotor2D?
    public var collideConnected: Bool
    public init(
        frameA: JointFrame2D = .init(),
        frameB: JointFrame2D = .init(),
        spring: JointSpring2D? = .init(hertz: 4, dampingRatio: 0.7),
        limits: JointLimits2D? = nil,
        motor: JointMotor2D? = nil,
        collideConnected: Bool = false
    ) {
        self.frameA = frameA
        self.frameB = frameB
        self.spring = spring
        self.limits = limits
        self.motor = motor
        self.collideConnected = collideConnected
    }
    func validate() throws(PhysicsJoint2DError) {
        guard frameA.isValid,
            frameB.isValid,
            spring?.isValid != false,
            limits?.isValid != false,
            motor?.isValid != false else { throw .invalidSettings }
    }
}

extension PhysicsJoint2DDescriptor {
    @MainActor
    public static func wheel(entityA: Entity, entityB: Entity, settings: WheelJoint2DSettings = .init()) throws(PhysicsJoint2DError) -> PhysicsJoint2DDescriptor {
        try validatePair(entityA, entityB)
        try settings.validate()
        return PhysicsJoint2DDescriptor(joint: .wheel(entityA.id, entityB.id, settings))
    }
}
