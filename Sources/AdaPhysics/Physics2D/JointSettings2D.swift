import AdaECS
import box2d
import Math

public enum PhysicsJoint2DError: Error, Equatable, Sendable {
    case invalidSettings
    case invalidBodyPair
    case missingBody
    case nativeCreationFailed
    case notConnected
    case unsupportedControl
}

/// A body-local physical frame. Entity scale does not rescale joint anchors.
public struct JointFrame2D: Codable, Equatable, Sendable {
    public var position: Vector2
    public var angle: Float
    public init(position: Vector2 = .zero, angle: Float = 0) {
        self.position = position
        self.angle = angle
    }
    var isValid: Bool { position.x.isFinite && position.y.isFinite && angle.isFinite }
    var native: b2Transform { b2Transform(p: position.b2Vec, q: b2MakeRot(angle)) }
}

public struct JointSpring2D: Codable, Equatable, Sendable {
    public var hertz: Float
    public var dampingRatio: Float
    public init(hertz: Float, dampingRatio: Float = 1) { self.hertz = hertz; self.dampingRatio = dampingRatio }
    var isValid: Bool { hertz.isFinite && hertz >= 0 && dampingRatio.isFinite && dampingRatio >= 0 }
}

public struct JointLimits2D: Codable, Equatable, Sendable {
    public var lower: Float
    public var upper: Float
    public init(lower: Float, upper: Float) { self.lower = lower; self.upper = upper }
    var isValid: Bool { lower.isFinite && upper.isFinite && lower <= upper }
}

/// Speed uses meters/second or radians/second; maximum effort uses newtons or newton-meters.
public struct JointMotor2D: Codable, Equatable, Sendable {
    public var speed: Float
    public var maximumEffort: Float
    public init(speed: Float, maximumEffort: Float) { self.speed = speed; self.maximumEffort = maximumEffort }
    var isValid: Bool { speed.isFinite && maximumEffort.isFinite && maximumEffort >= 0 }
}

public struct DistanceJoint2DSettings: Codable, Equatable, Sendable {
    public var frameA: JointFrame2D
    public var frameB: JointFrame2D
    public var length: Float
    public var spring: JointSpring2D?
    public var limits: JointLimits2D?
    public var motor: JointMotor2D?
    public var collideConnected: Bool
    public init(
        length: Float,
        frameA: JointFrame2D = .init(),
        frameB: JointFrame2D = .init(),
        spring: JointSpring2D? = nil,
        limits: JointLimits2D? = nil,
        motor: JointMotor2D? = nil,
        collideConnected: Bool = false
    ) {
        self.length = length
        self.frameA = frameA
        self.frameB = frameB
        self.spring = spring
        self.limits = limits
        self.motor = motor
        self.collideConnected = collideConnected
    }
    func validate() throws(PhysicsJoint2DError) {
        guard frameA.isValid, frameB.isValid, length.isFinite, length > 0,
            spring?.isValid != false, limits?.isValid != false, motor?.isValid != false,
            (limits?.lower ?? 0) >= 0 else { throw PhysicsJoint2DError.invalidSettings }
    }
}

extension PhysicsJoint2DDescriptor {
    /// Creates a rigid distance constraint, spring or limited/motorized cable.
    @MainActor
    public static func distance(entityA: Entity, entityB: Entity, settings: DistanceJoint2DSettings) throws(PhysicsJoint2DError) -> PhysicsJoint2DDescriptor {
        try validatePair(entityA, entityB)
        try settings.validate()
        return PhysicsJoint2DDescriptor(joint: .distance(entityA.id, entityB.id, settings))
    }

    @MainActor
    static func validatePair(_ a: Entity, _ b: Entity) throws(PhysicsJoint2DError) {
        guard a.id != b.id, let world = a.world, world === b.world else { throw PhysicsJoint2DError.invalidBodyPair }
    }
}
