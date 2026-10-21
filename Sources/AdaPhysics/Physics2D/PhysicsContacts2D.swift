import AdaECS
import box2d
import Math

// A handle keeps this identity alive, never its world. A newly allocated world cannot reuse its scope.
final class ContactScope2D: Sendable {}

/// Ephemeral native contact identity, scoped to one world lifetime. Not a serializable durable identifier.
public struct Contact2DID: Hashable, Sendable {
    private let scope: ContactScope2D
    private let index: Int32
    private let world: UInt16
    private let generation: UInt32

    init(_ native: b2ContactId, scope: ContactScope2D) {
        self.scope = scope; index = native.index1; world = native.world0; generation = native.generation
    }
    var native: b2ContactId { b2ContactId(index1: index, world0: world, padding: 0, generation: generation) }
    func belongs(to scope: ContactScope2D) -> Bool { self.scope === scope }
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.scope === rhs.scope && lhs.index == rhs.index && lhs.world == rhs.world && lhs.generation == rhs.generation
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(scope)); hasher.combine(index); hasher.combine(world); hasher.combine(generation)
    }
}

public enum Contact2DPhase: Sendable { case preSolve, postSolve }

/// Copied native manifold point. Anchors are world-space offsets from each body's center of mass.
/// Global positions reconstruct these cached offsets against the current centers; they are not time-of-impact coordinates.
public struct ContactPoint2D: Sendable {
    public let id: UInt16
    public let persisted: Bool
    public let anchorA: Vector2
    public let anchorB: Vector2
    public let globalAnchorA: PhysicsPosition2D
    public let globalAnchorB: PhysicsPosition2D
    public let globalPoint: PhysicsPosition2D
    /// Nearby midpoint relative to the coordinate origin when captured.
    public let point: Vector2
    /// Negative means penetration; speculative points can have positive separation and zero total impulse.
    public let separation: Float
    public let normalImpulse: Float
    public let tangentImpulse: Float
    /// Includes substeps, warm start and restitution. Use it to detect actual speculative interaction.
    public let totalNormalImpulse: Float
    /// Available only for post-solve data with native hit reporting enabled; nil during pre-solve.
    public let normalVelocity: Float?
}

/// Immutable data. Entity/shape IDs are references; copied geometry/impulses remain readable after deletion.
public struct Contact2DSnapshot: Sendable {
    public let id: Contact2DID
    public let entityA: Entity.ID
    public let entityB: Entity.ID
    public let shapeA: UInt64
    public let shapeB: UInt64
    /// Native ordering: normal points from shape A to B.
    public let manifold: Manifold2D
}

@MainActor
extension PhysicsWorld2D {
    public func isValid(_ contact: Contact2DID) -> Bool {
        contact.belongs(to: contactScope) && b2Contact_IsValid(contact.native)
    }

    /// Last native manifold copied between steps. Expired or foreign-world handles return nil.
    public func contactSnapshot(for contact: Contact2DID) -> Contact2DSnapshot? {
        guard isValid(contact) else {
            return nil
        }
        return snapshot(b2Contact_GetData(contact.native))
    }

    /// Solid touching contacts for an owned rigid/collision/dynamic-character body. Sensors have a separate event stream.
    public func contacts(for entity: Entity) -> [Contact2DSnapshot] {
        guard let body = RuntimeJoint2D.body(entity), body.world === self, b2Body_IsValid(body.bodyId) else {
            return []
        }
        let capacity = b2Body_GetContactCapacity(body.bodyId)
        guard capacity > 0 else {
            return []
        }
        var data = Array(repeating: b2ContactData(), count: Int(capacity))
        let count = unsafe data.withUnsafeMutableBufferPointer { unsafe b2Body_GetContactData(body.bodyId, $0.baseAddress, capacity) }
        return data.prefix(Int(count)).compactMap { snapshot($0) }
    }

    /// Solid contacts for a per-shape query identifier. Shape IDs remain ephemeral within their owning world.
    public func contacts(forShape identifier: UInt64) -> [Contact2DSnapshot] {
        let shape = b2LoadShapeId(identifier)
        guard Int(shape.world0) + 1 == Int(worldId.index1), b2Shape_IsValid(shape) else {
            return []
        }
        let capacity = b2Shape_GetContactCapacity(shape)
        guard capacity > 0 else {
            return []
        }
        var data = Array(repeating: b2ContactData(), count: Int(capacity))
        let count = unsafe data.withUnsafeMutableBufferPointer { unsafe b2Shape_GetContactData(shape, $0.baseAddress, capacity) }
        return data.prefix(Int(count)).compactMap { snapshot($0) }
    }

    func snapshot(_ data: b2ContactData) -> Contact2DSnapshot? {
        let a = BoxShape2D(shape: data.shapeIdA)
        let b = BoxShape2D(shape: data.shapeIdB)
        guard a.isValid, b.isValid, let bodyA = a.body, let bodyB = b.body,
            bodyA.world === self, bodyB.world === self, let entityA = bodyA.entity, let entityB = bodyB.entity else {
            return nil
        }
        let velocities = b2Shape_AreHitEventsEnabled(data.shapeIdA) || b2Shape_AreHitEventsEnabled(data.shapeIdB)
        let manifold = makeManifold2D(
            data.manifold,
            bodyA: bodyA.bodyId,
            bodyB: bodyB.bodyId,
            origin: coordinateOrigin,
            phase: .postSolve,
            hasNormalVelocity: velocities
        )
        return Contact2DSnapshot(
            id: Contact2DID(data.contactId, scope: contactScope),
            entityA: entityA.id,
            entityB: entityB.id,
            shapeA: b2StoreShapeId(data.shapeIdA),
            shapeB: b2StoreShapeId(data.shapeIdB),
            manifold: manifold
        )
    }
}

func makeManifold2D(
    _ manifold: b2Manifold,
    bodyA: b2BodyId,
    bodyB: b2BodyId,
    origin: PhysicsPosition2D,
    phase: Contact2DPhase,
    hasNormalVelocity: Bool
) -> Manifold2D {
    let centerA = PhysicsPosition2D(b2Body_GetWorldCenter(bodyA))
    let centerB = PhysicsPosition2D(b2Body_GetWorldCenter(bodyB))
    let points = (0..<max(0, min(2, Int(manifold.pointCount)))).map { index in
        let point = index == 0 ? manifold.points.0 : manifold.points.1
        let a = centerA.offset(by: point.anchorA.asVector2)
        let b = centerB.offset(by: point.anchorB.asVector2)
        let middle = PhysicsPosition2D(x: a.x + (b.x - a.x) * 0.5, y: a.y + (b.y - a.y) * 0.5)
        return ContactPoint2D(
            id: point.id,
            persisted: point.persisted,
            anchorA: point.anchorA.asVector2,
            anchorB: point.anchorB.asVector2,
            globalAnchorA: a,
            globalAnchorB: b,
            globalPoint: middle,
            point: middle.displacement(from: origin),
            separation: point.separation,
            normalImpulse: point.normalImpulse,
            tangentImpulse: point.tangentImpulse,
            totalNormalImpulse: point.totalNormalImpulse,
            normalVelocity: phase == .postSolve && hasNormalVelocity ? point.normalVelocity : nil
        )
    }
    return Manifold2D(normal: manifold.normal.asVector2, rollingImpulse: manifold.rollingImpulse, points: points, phase: phase)
}
