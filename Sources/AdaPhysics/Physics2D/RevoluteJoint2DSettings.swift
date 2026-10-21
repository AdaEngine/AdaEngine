import AdaECS
import Math

/// A hinge angle is measured between its two local frames; all angles use radians.
public struct RevoluteJoint2DSettings: Codable, Equatable, Sendable {
    public var frameA: JointFrame2D
    public var frameB: JointFrame2D
    public var targetAngle: Float
    public var spring: JointSpring2D?
    public var limits: JointLimits2D?
    public var motor: JointMotor2D?
    public var collideConnected: Bool
    public init(
        frameA: JointFrame2D = .init(),
        frameB: JointFrame2D = .init(),
        targetAngle: Float = 0,
        spring: JointSpring2D? = nil,
        limits: JointLimits2D? = nil,
        motor: JointMotor2D? = nil,
        collideConnected: Bool = false
    ) {
        self.frameA = frameA
        self.frameB = frameB
        self.targetAngle = targetAngle
        self.spring = spring
        self.limits = limits
        self.motor = motor
        self.collideConnected = collideConnected
    }
    func validate() throws(PhysicsJoint2DError) {
        guard frameA.isValid, frameB.isValid, targetAngle.isFinite, abs(targetAngle) <= .pi,
            spring?.isValid != false, limits?.isValid != false, motor?.isValid != false,
            (limits?.lower ?? 0) >= -0.99 * .pi, (limits?.upper ?? 0) <= 0.99 * .pi else { throw .invalidSettings }
    }
}

extension PhysicsJoint2DDescriptor {
    @MainActor
    public static func revolute(entityA: Entity, entityB: Entity, settings: RevoluteJoint2DSettings = .init()) throws(PhysicsJoint2DError) -> PhysicsJoint2DDescriptor {
        try validatePair(entityA, entityB)
        try settings.validate()
        return PhysicsJoint2DDescriptor(joint: .hinge(entityA.id, entityB.id, settings))
    }

    /// Pins a body to a fixed world point, with angle zero at its initial orientation.
    @MainActor
    public static func revolute(
        entity: Entity,
        worldAnchor: Vector2,
        targetAngle: Float = 0,
        spring: JointSpring2D? = nil,
        limits: JointLimits2D? = nil,
        motor: JointMotor2D? = nil
    ) throws(PhysicsJoint2DError) -> PhysicsJoint2DDescriptor {
        guard entity.world != nil, JointFrame2D(position: worldAnchor).isValid else { throw .invalidSettings }
        let settings = RevoluteJoint2DSettings(targetAngle: targetAngle, spring: spring, limits: limits, motor: motor)
        try settings.validate()
        return PhysicsJoint2DDescriptor(joint: .worldHinge(entity.id, worldAnchor, settings))
    }
}

@MainActor
extension PhysicsJoint2DDescriptor {
    /// Hinge to an exact global anchor, independent of later render-origin changes.
    public static func revolute(
        entity: Entity, globalAnchor: PhysicsPosition2D, settings: RevoluteJoint2DSettings = .init()
    ) throws(PhysicsJoint2DError) -> PhysicsJoint2DDescriptor {
        guard entity.world != nil, globalAnchor.isFinite else { throw .invalidSettings }
        try settings.validate()
        return PhysicsJoint2DDescriptor(joint: .globalHinge(entity.id, globalAnchor, settings))
    }
}
