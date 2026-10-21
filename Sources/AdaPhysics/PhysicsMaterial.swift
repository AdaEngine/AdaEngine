/// Invalid physical material inputs cannot be passed to native creation/update APIs.
public enum PhysicsMaterialError: Error, Equatable, Sendable { case invalidProperties }

/// Immutable physical surface resource. Rolling resistance and surface speed apply to 2D physics.
public final class PhysicsMaterial: Codable, Sendable {
    public let friction: Float
    public let restitution: Float
    public let density: Float
    public let rollingResistance: Float
    /// Signed native tangent speed for conveyor surfaces, in physical units per second.
    public let surfaceSpeed: Float

    internal init(friction: Float, restitution: Float, density: Float, rollingResistance: Float = 0, surfaceSpeed: Float = 0) {
        self.friction = friction
        self.restitution = restitution
        self.density = density
        self.rollingResistance = rollingResistance
        self.surfaceSpeed = surfaceSpeed
    }

    /// Existing material factory, preserving its source signature and defaults.
    public static func generate(friction: Float, restitution: Float, density: Float) -> PhysicsMaterial {
        PhysicsMaterial(friction: friction, restitution: restitution, density: density)
    }

    /// Validated material including optional rolling resistance and conveyor speed.
    public static func generate2D(
        friction: Float = 0.6,
        restitution: Float = 0,
        density: Float = 1,
        rollingResistance: Float = 0,
        surfaceSpeed: Float = 0
    ) throws(PhysicsMaterialError) -> PhysicsMaterial {
        let material = PhysicsMaterial(
            friction: friction,
            restitution: restitution,
            density: density,
            rollingResistance: rollingResistance,
            surfaceSpeed: surfaceSpeed
        )
        try material.validate()
        return material
    }

    private func validate() throws(PhysicsMaterialError) {
        guard friction.isFinite, friction >= 0, restitution.isFinite, restitution >= 0, density.isFinite, density >= 0,
            rollingResistance.isFinite, rollingResistance >= 0, surfaceSpeed.isFinite else { throw .invalidProperties }
    }

    private enum CodingKeys: CodingKey { case friction, restitution, density, rollingResistance, surfaceSpeed }

    public convenience init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            friction: try values.decode(Float.self, forKey: .friction),
            restitution: try values.decode(Float.self, forKey: .restitution),
            density: try values.decode(Float.self, forKey: .density),
            rollingResistance: try values.decodeIfPresent(Float.self, forKey: .rollingResistance) ?? 0,
            surfaceSpeed: try values.decodeIfPresent(Float.self, forKey: .surfaceSpeed) ?? 0
        )
        try validate()
    }

    public func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(friction, forKey: .friction)
        try values.encode(restitution, forKey: .restitution)
        try values.encode(density, forKey: .density)
        try values.encode(rollingResistance, forKey: .rollingResistance)
        try values.encode(surfaceSpeed, forKey: .surfaceSpeed)
    }

    public static let `default` = PhysicsMaterial(friction: 0.6, restitution: 0, density: 1)
}
