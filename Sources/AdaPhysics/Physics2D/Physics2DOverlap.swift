import AdaECS
import AdaTransform
import box2d
import Math

/// One overlapping native shape; compound bodies and chains may yield several hits for one entity.
public struct Overlap2DHit: Sendable {
    public let entity: Entity
    /// Ephemeral native identifier, only meaningful in the owning world's current lifetime.
    public let shapeID: UInt64
    public let isSensor: Bool
}

@MainActor
extension PhysicsWorld2D {
    /// Exact point overlap, including shape boundaries according to Box2D's distance query.
    /// Results are per shape, ordered by entity ID then shape ID. Invalid points return no hits.
    public func overlap(
        at point: Vector2,
        mask: CollisionGroup = .all,
        includeSensors: Bool = true,
        excluding entities: Set<Entity.ID> = []
    ) -> [Overlap2DHit] {
        overlap(atGlobal: coordinateOrigin.offset(by: point), mask: mask, includeSensors: includeSensors, excluding: entities)
    }

    /// Exact point overlap using global Double input.
    public func overlap(
        atGlobal point: PhysicsPosition2D,
        mask: CollisionGroup = .all,
        includeSensors: Bool = true,
        excluding entities: Set<Entity.ID> = []
    ) -> [Overlap2DHit] {
        guard point.isFinite, !mask.isEmpty else {
            return []
        }
        var center = b2Vec2_zero
        var proxy = unsafe b2MakeProxy(&center, 1, 0)
        return unsafe overlapProxy(&proxy, origin: point, mask: mask, includeSensors: includeSensors, excluding: entities)
    }

    /// Broad-phase AABB candidates, not an exact shape-vs-rectangle intersection test.
    /// Use the convex-shape overload for exact geometry. Negative/nonfinite bounds return no hits.
    public func overlap(
        in bounds: Rect,
        mask: CollisionGroup = .all,
        includeSensors: Bool = true,
        excluding entities: Set<Entity.ID> = []
    ) -> [Overlap2DHit] {
        overlap(in: bounds, relativeTo: coordinateOrigin, mask: mask, includeSensors: includeSensors, excluding: entities)
    }

    /// Broad-phase bounds expressed near an exact global origin; bounds themselves remain Float.
    public func overlap(
        in bounds: Rect,
        relativeTo origin: PhysicsPosition2D,
        mask: CollisionGroup = .all,
        includeSensors: Bool = true,
        excluding entities: Set<Entity.ID> = []
    ) -> [Overlap2DHit] {
        guard origin.isFinite else {
            return []
        }
        guard bounds.minX.isFinite, bounds.minY.isFinite, bounds.maxX.isFinite, bounds.maxY.isFinite,
            bounds.width >= 0, bounds.height >= 0, !mask.isEmpty else {
            return []
        }
        var collector = Overlap2DCollector(includeSensors: includeSensors, excluding: entities)
        let native = b2AABB(lowerBound: Vector2(bounds.minX, bounds.minY).b2Vec, upperBound: Vector2(bounds.maxX, bounds.maxY).b2Vec)
        var filter = b2DefaultQueryFilter()
        filter.categoryBits = UInt64.max
        filter.maskBits = mask.rawValue
        // Native traversal is synchronous. Both the context and its result storage stay alive here.
        _ = unsafe withUnsafeMutablePointer(to: &collector) {
            unsafe b2World_OverlapAABB(worldId, origin.native, native, filter, PhysicsWorld2D_Overlap, $0)
        }
        return collector.sortedHits
    }

    /// Exact overlap with a circle, capsule, convex polygon, box or two-sided segment at an XY pose.
    /// Chain resources are not convex query volumes and throw `unsupportedShape`.
    /// Sensors are included by default; call between simulation steps on the main actor.
    public func overlap(
        _ shape: Shape2DResource,
        at pose: Transform = Transform(),
        mask: CollisionGroup = .all,
        includeSensors: Bool = true,
        excluding entities: Set<Entity.ID> = []
    ) throws -> [Overlap2DHit] {
        var proxy = try NativeConvexQuery2D.make(shape, pose: pose)
        guard !mask.isEmpty else {
            return []
        }
        return unsafe overlapProxy(&proxy, origin: coordinateOrigin.offset(by: pose.position.xy), mask: mask, includeSensors: includeSensors, excluding: entities)
    }

    /// Exact convex overlap at a global position; rotation and scale describe local geometry.
    public func overlap(
        _ shape: Shape2DResource,
        atGlobal position: PhysicsPosition2D,
        rotation: Quat = .identity,
        scale: Vector2 = Vector2(1),
        mask: CollisionGroup = .all,
        includeSensors: Bool = true,
        excluding entities: Set<Entity.ID> = []
    ) throws -> [Overlap2DHit] {
        guard position.isFinite else { throw Physics2DQueryError.invalidPose }
        var proxy = try NativeConvexQuery2D.make(shape, pose: Transform(rotation: rotation, scale: [scale.x, scale.y, 1]))
        return unsafe overlapProxy(&proxy, origin: position, mask: mask, includeSensors: includeSensors, excluding: entities)
    }

    func overlapProxy(
        _ proxy: UnsafePointer<b2ShapeProxy>,
        origin: PhysicsPosition2D,
        mask: CollisionGroup,
        includeSensors: Bool,
        excluding entities: Set<Entity.ID>
    ) -> [Overlap2DHit] {
        var collector = Overlap2DCollector(includeSensors: includeSensors, excluding: entities)
        var filter = b2DefaultQueryFilter()
        filter.categoryBits = UInt64.max
        filter.maskBits = mask.rawValue
        _ = unsafe withUnsafeMutablePointer(to: &collector) {
            unsafe b2World_OverlapShape(worldId, origin.native, proxy, filter, PhysicsWorld2D_Overlap, $0)
        }
        return collector.sortedHits
    }
}

private struct Overlap2DCollector {
    let includeSensors: Bool
    let excluding: Set<Entity.ID>
    var hits: [Overlap2DHit] = []
    var seen: Set<UInt64> = []

    var sortedHits: [Overlap2DHit] {
        hits.sorted { $0.entity.id == $1.entity.id ? $0.shapeID < $1.shapeID : $0.entity.id < $1.entity.id }
    }
}

private func PhysicsWorld2D_Overlap(_ id: b2ShapeId, _ context: UnsafeMutableRawPointer?) -> Bool {
    let shape = BoxShape2D(shape: id)
    guard shape.isValid, let entity = shape.body?.entity, let context = unsafe context else {
        return true
    }
    let collector = unsafe context.assumingMemoryBound(to: Overlap2DCollector.self)
    if unsafe collector.pointee.excluding.contains(entity.id) || (!collector.pointee.includeSensors && shape.isSensor) {
        return true
    }
    let stored = b2StoreShapeId(id)
    if unsafe collector.pointee.seen.insert(stored).inserted {
        unsafe collector.pointee.hits.append(Overlap2DHit(entity: entity, shapeID: stored, isSensor: shape.isSensor))
    }
    return true
}
