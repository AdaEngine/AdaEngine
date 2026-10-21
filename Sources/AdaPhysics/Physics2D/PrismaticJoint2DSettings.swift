import AdaECS

/// Slides along local frame A's X axis and locks relative frame rotation.
public struct PrismaticJoint2DSettings: Codable, Equatable, Sendable {
    public var frameA: JointFrame2D
    public var frameB: JointFrame2D
    public var targetTranslation: Float
    public var spring: JointSpring2D?
    public var limits: JointLimits2D?
    public var motor: JointMotor2D?
    public var collideConnected: Bool
    public init(
        frameA: JointFrame2D = .init(),
        frameB: JointFrame2D = .init(),
        targetTranslation: Float = 0,
        spring: JointSpring2D? = nil,
        limits: JointLimits2D? = nil,
        motor: JointMotor2D? = nil,
        collideConnected: Bool = false
    ) {
        self.frameA = frameA
        self.frameB = frameB
        self.targetTranslation = targetTranslation
        self.spring = spring
        self.limits = limits
        self.motor = motor
        self.collideConnected = collideConnected
    }
    func validate() throws(PhysicsJoint2DError) {
        guard frameA.isValid,
            frameB.isValid,
            targetTranslation.isFinite,
            spring?.isValid != false,
            limits?.isValid != false,
            motor?.isValid != false else { throw .invalidSettings }
    }
}

extension PhysicsJoint2DDescriptor {
    @MainActor
    public static func prismatic(entityA: Entity, entityB: Entity, settings: PrismaticJoint2DSettings = .init()) throws(PhysicsJoint2DError) -> PhysicsJoint2DDescriptor {
        try validatePair(entityA, entityB)
        try settings.validate()
        return PhysicsJoint2DDescriptor(joint: .prismatic(entityA.id, entityB.id, settings))
    }
}
