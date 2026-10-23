import AdaECS
import box2d
import Math

/// An exact global 2D position. Distances, local geometry, velocities and rotations remain Float.
/// Construct from Double inputs: widening a previously rounded Float cannot recover lost precision.
public struct PhysicsPosition2D: Codable, Hashable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public static let zero = Self(x: 0, y: 0)
    public var isFinite: Bool { x.isFinite && y.isFinite }

    /// A nearby displacement, subtracting before narrowing to Float.
    public func displacement(from origin: Self) -> Vector2 {
        Vector2(Float(x - origin.x), Float(y - origin.y))
    }

    public func offset(by displacement: Vector2) -> Self {
        Self(x: x + Double(displacement.x), y: y + Double(displacement.y))
    }

    var native: b2Pos { b2Pos(x: x, y: y) }
    init(_ native: b2Pos) { self.init(x: native.x, y: native.y) }
}

extension PhysicsBody2DComponent {
    /// Exact global position while the native body exists. Nil before creation or after removal.
    public var precisePosition: PhysicsPosition2D? {
        guard let body = runtimeBody, b2Body_IsValid(body.bodyId) else {
            return nil
        }
        return PhysicsPosition2D(b2Body_GetPosition(body.bodyId))
    }

    /// Teleports an existing body using exact global coordinates. Returns false for invalid input or no body.
    /// An ECS-owned precise position should also be updated when authoritative component sync is active.
    @discardableResult
    public func setGlobalPosition(_ position: PhysicsPosition2D, angle: Angle? = nil) -> Bool {
        guard position.isFinite, let body = runtimeBody, b2Body_IsValid(body.bodyId) else {
            return false
        }
        let rotation = angle.map { b2MakeRot($0.radians) } ?? b2Body_GetRotation(body.bodyId)
        guard rotation.c.isFinite, rotation.s.isFinite else {
            return false
        }
        b2Body_SetTransform(body.bodyId, position.native, rotation)
        return true
    }
}

/// A ray hit with an exact global point and Float physical distance/normal.
public struct PreciseRaycast2DHit: Sendable {
    public let entity: Entity
    public let point: PhysicsPosition2D
    public let normal: Vector2
    public let distance: Float
}

extension PhysicsWorld2D {
    /// Casts from an exact global origin along a finite nearby displacement.
    /// Initially overlapping shapes are ignored, matching the legacy ray API.
    public func raycast(
        from origin: PhysicsPosition2D,
        translation: Vector2,
        query: CollisionCastQueryType = .all,
        mask: CollisionGroup = .all
    ) -> [PreciseRaycast2DHit] {
        let length = translation.squaredLength.squareRoot()
        guard origin.isFinite, length.isFinite, length > 0, !mask.isEmpty else {
            return []
        }
        var filter = b2DefaultQueryFilter()
        filter.categoryBits = UInt64.max
        filter.maskBits = mask.rawValue
        var collector = PreciseRayCollector2D(length: length, query: query)
        _ = unsafe withUnsafeMutablePointer(to: &collector) {
            unsafe b2World_CastRay(worldId, origin.native, translation.b2Vec, filter, PreciseRaycast2D, $0)
        }
        return collector.hits.sorted { $0.distance < $1.distance }
    }
}

private struct PreciseRayCollector2D {
    let length: Float
    let query: CollisionCastQueryType
    var hits: [PreciseRaycast2DHit] = []
}

private func PreciseRaycast2D(_ id: b2ShapeId, _ point: b2Pos, _ normal: b2Vec2, _ fraction: Float, _ context: UnsafeMutableRawPointer?) -> Float {
    guard fraction != 0 || normal.x != 0 || normal.y != 0 else {
        return -1
    }
    let shape = BoxShape2D(shape: id)
    guard shape.isValid, let entity = shape.body?.entity, let context = unsafe context else {
        return -1
    }
    let collector = unsafe context.assumingMemoryBound(to: PreciseRayCollector2D.self)
    let hit = unsafe PreciseRaycast2DHit(entity: entity, point: PhysicsPosition2D(point), normal: normal.asVector2, distance: collector.pointee.length * fraction)
    if unsafe collector.pointee.query == .first {
        if unsafe collector.pointee.hits.isEmpty { unsafe collector.pointee.hits.append(hit) } else { unsafe collector.pointee.hits[0] = hit }
        return fraction
    }
    unsafe collector.pointee.hits.append(hit)
    return 1
}

@MainActor
extension PhysicsBody2DComponent {
    public var preciseWorldCenter: PhysicsPosition2D? {
        guard let body = runtimeBody, b2Body_IsValid(body.bodyId) else {
            return nil
        }
        return PhysicsPosition2D(b2Body_GetWorldCenter(body.bodyId))
    }

    /// Applies force at an exact global point; torque uses a precise nearby lever arm.
    @discardableResult
    public func applyForce(force: Vector2, atGlobalPoint point: PhysicsPosition2D, wake: Bool) -> Bool {
        guard point.isFinite, force.x.isFinite, force.y.isFinite, let body = runtimeBody, b2Body_IsValid(body.bodyId) else {
            return false
        }
        b2Body_ApplyForce(body.bodyId, force.b2Vec, point.native, wake)
        return true
    }

    /// Applies an impulse at an exact global point without narrowing its world coordinates.
    @discardableResult
    public func applyLinearImpulse(_ impulse: Vector2, atGlobalPoint point: PhysicsPosition2D, wake: Bool) -> Bool {
        guard point.isFinite, impulse.x.isFinite, impulse.y.isFinite, let body = runtimeBody, b2Body_IsValid(body.bodyId) else {
            return false
        }
        b2Body_ApplyLinearImpulse(body.bodyId, impulse.b2Vec, point.native, wake)
        return true
    }
}
