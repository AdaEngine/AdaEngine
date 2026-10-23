import AdaECS

/// Aligns two frames. A nil spring is rigid; nonzero hertz makes a soft weld.
public struct WeldJoint2DSettings: Codable, Equatable, Sendable {
    public var frameA: JointFrame2D
    public var frameB: JointFrame2D
    public var linearSpring: JointSpring2D?
    public var angularSpring: JointSpring2D?
    public var collideConnected: Bool
    public init(
        frameA: JointFrame2D = .init(),
        frameB: JointFrame2D = .init(),
        linearSpring: JointSpring2D? = nil,
        angularSpring: JointSpring2D? = nil,
        collideConnected: Bool = false
    ) {
        self.frameA = frameA
        self.frameB = frameB
        self.linearSpring = linearSpring
        self.angularSpring = angularSpring
        self.collideConnected = collideConnected
    }
    func validate() throws(PhysicsJoint2DError) {
        guard frameA.isValid,
            frameB.isValid,
            linearSpring?.isValid != false,
            angularSpring?.isValid != false else { throw .invalidSettings }
    }
}

extension PhysicsJoint2DDescriptor {
    @MainActor
    public static func weld(entityA: Entity, entityB: Entity, settings: WeldJoint2DSettings = .init()) throws(PhysicsJoint2DError) -> PhysicsJoint2DDescriptor {
        try validatePair(entityA, entityB)
        try settings.validate()
        return PhysicsJoint2DDescriptor(joint: .weld(entityA.id, entityB.id, settings))
    }

    /// Suppresses this pair's collisions until the joint is removed, without constraining movement.
    @MainActor
    public static func filter(entityA: Entity, entityB: Entity) throws(PhysicsJoint2DError) -> PhysicsJoint2DDescriptor {
        try validatePair(entityA, entityB)
        return PhysicsJoint2DDescriptor(joint: .filter(entityA.id, entityB.id))
    }
}
