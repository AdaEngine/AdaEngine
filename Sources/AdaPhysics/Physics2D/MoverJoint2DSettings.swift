import AdaECS
import Math

/// Drives relative velocity in world X/Y with independent force caps; does not affect rotation.
public struct MoverJoint2DSettings: Codable, Equatable, Sendable {
    public var linearVelocity: Vector2
    public var maximumVelocityForce: Vector2
    public var collideConnected: Bool
    public init(
        linearVelocity: Vector2 = .zero,
        maximumVelocityForce: Vector2 = [1000, 0],
        collideConnected: Bool = true
    ) {
        self.linearVelocity = linearVelocity
        self.maximumVelocityForce = maximumVelocityForce
        self.collideConnected = collideConnected
    }
    func validate() throws(PhysicsJoint2DError) {
        guard linearVelocity.x.isFinite && linearVelocity.y.isFinite,
            maximumVelocityForce.x.isFinite && maximumVelocityForce.y.isFinite,
            maximumVelocityForce.x >= 0 && maximumVelocityForce.y >= 0 else { throw .invalidSettings }
    }
}

extension PhysicsJoint2DDescriptor {
    @MainActor
    public static func mover(entityA: Entity, entityB: Entity, settings: MoverJoint2DSettings = .init()) throws(PhysicsJoint2DError) -> PhysicsJoint2DDescriptor {
        try validatePair(entityA, entityB)
        try settings.validate()
        return PhysicsJoint2DDescriptor(joint: .mover(entityA.id, entityB.id, settings))
    }
}
