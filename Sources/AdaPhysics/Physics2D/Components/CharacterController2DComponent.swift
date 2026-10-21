import AdaECS
import box2d
import Math

public enum CharacterController2DError: Error, Equatable, Sendable {
    case invalidConfiguration
    case invalidMotion
    case conflictingBody
    case dynamicRequiresECS
}

/// Upright capsule dimensions use physical world units; visual scale/rotation do not resize it.
public struct CharacterController2DSettings: Codable, Equatable, Sendable {
    public var radius: Float = 0.35
    public var height: Float = 1.8
    public var acceleration: Float = 14
    public var deceleration: Float = 20
    public var jumpSpeed: Float = 5
    public var maximumFallSpeed: Float = 50
    public var minimumGroundNormalY: Float = 0.707107
    public var groundSnapDistance: Float = 0.16
    public var gravityScale: Float = 1
    public var skinWidth: Float = 0.01

    public init(radius: Float = 0.35, height: Float = 1.8) { self.radius = radius; self.height = height }

    func validate() throws(CharacterController2DError) {
        let slop = 0.005 * b2GetLengthUnitsPerMeter()
        guard radius.isFinite, height.isFinite, acceleration.isFinite, deceleration.isFinite, jumpSpeed.isFinite,
            maximumFallSpeed.isFinite, minimumGroundNormalY.isFinite, groundSnapDistance.isFinite, gravityScale.isFinite, skinWidth.isFinite,
            radius > 2 * slop, height > 2 * radius + slop,
            acceleration >= 0, deceleration >= 0, jumpSpeed >= 0, maximumFallSpeed > 0,
            minimumGroundNormalY > 0, minimumGroundNormalY <= 1, groundSnapDistance >= 0,
            gravityScale >= 0, skinWidth >= 0, skinWidth < radius else { throw .invalidConfiguration }
    }

    var capsule: b2Capsule {
        b2Capsule(center1: b2Vec2(x: 0, y: radius), center2: b2Vec2(x: 0, y: height - radius), radius: radius + skinWidth)
    }
}

/// Upright capsule controller. Transform.position is its bottom, matching the 3D controller.
/// Use on a root entity without PhysicsBody2DComponent/Collision2DComponent. It ignores sensors,
/// `.query` is virtual; `.dynamic` owns a native capsule and mover/pogo support.
@Component
public struct CharacterController2DComponent: Codable, Sendable {
    public var settings: CharacterController2DSettings
    public var mode: CharacterController2DMode = .query
    public var dynamics = CharacterController2DDynamics()
    public var filter = CollisionFilter()
    /// Requested horizontal world velocity; Y is ignored.
    public var desiredVelocity: Vector2 = .zero
    /// Press-edge request, consumed on the next fixed tick even when airborne.
    public var jumpRequested = false
    public var resetMotion = false
    public internal(set) var isGrounded = false
    public internal(set) var groundNormal: Vector2 = .zero
    public internal(set) var groundPoint: Vector2?
    public internal(set) var groundEntityID: Entity.ID?
    public internal(set) var velocity: Vector2 = .zero
    public internal(set) var lastError: CharacterController2DError?
    var runtime: CharacterRuntime2D?
    var horizontalVelocity: Float = 0
    var verticalVelocity: Float = 0
    var jumping = false
    var lastPosition: Vector2?

    public init(radius: Float = 0.35, height: Float = 1.8) { settings = .init(radius: radius, height: height) }
    public init(settings: CharacterController2DSettings) { self.settings = settings }

    private enum CodingKeys: CodingKey { case settings, filter, mode, dynamics }
    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        settings = try values.decodeIfPresent(CharacterController2DSettings.self, forKey: .settings) ?? .init()
        filter = try values.decodeIfPresent(CollisionFilter.self, forKey: .filter) ?? .init()
        mode = try values.decodeIfPresent(CharacterController2DMode.self, forKey: .mode) ?? .query
        dynamics = try values.decodeIfPresent(CharacterController2DDynamics.self, forKey: .dynamics) ?? .init()
        try settings.validate()
        try dynamics.validate()
    }
}
