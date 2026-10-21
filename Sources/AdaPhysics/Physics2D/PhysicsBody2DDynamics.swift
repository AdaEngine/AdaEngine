import box2d

public enum PhysicsBody2DSettingsError: Error, Equatable, Sendable {
    case invalidDynamics
    case invalidMotion
}

/// Authored continuous collision and velocity-decay settings. Old bodies retain native defaults.
public struct PhysicsBody2DDynamics: Codable, Equatable, Sendable {
    /// Continuous checks against dynamic/kinematic bodies, excluding other bullets. Not a projectile timing guarantee.
    public var isBullet: Bool = false
    /// Nonnegative continuous-collision safety factor; Box2D recommends 0.01...0.5. Smaller values check more often.
    public var safetyFactor: Float = 0.5
    /// Velocity decay coefficient in inverse seconds; zero means no damping.
    public var linearDamping: Float = 0
    public var angularDamping: Float = 0

    public init() {}
    func validate() throws(PhysicsBody2DSettingsError) {
        guard safetyFactor.isFinite, safetyFactor >= 0, linearDamping.isFinite, linearDamping >= 0,
            angularDamping.isFinite, angularDamping >= 0 else { throw .invalidDynamics }
    }

    func apply(to definition: inout b2BodyDef) {
        definition.isBullet = isBullet
        definition.safetyFactor = safetyFactor
        definition.linearDamping = linearDamping
        definition.angularDamping = angularDamping
    }
}

@MainActor
extension PhysicsBody2DComponent {
    /// Validates atomically, updates an existing native body without recreation and wakes it.
    /// Before creation, stores the settings used by the first physics sync. Invalid settings leave it unchanged.
    public mutating func configureDynamics(_ settings: PhysicsBody2DDynamics) throws(PhysicsBody2DSettingsError) {
        try settings.validate()
        guard settings != dynamics else {
            return
        }
        dynamics = settings
        guard let body = runtimeBody, b2Body_IsValid(body.bodyId) else {
            return
        }
        b2Body_SetBullet(body.bodyId, settings.isBullet)
        b2Body_SetSafetyFactor(body.bodyId, settings.safetyFactor)
        b2Body_SetLinearDamping(body.bodyId, settings.linearDamping)
        b2Body_SetAngularDamping(body.bodyId, settings.angularDamping)
        b2Body_SetAwake(body.bodyId, true)
    }
}
