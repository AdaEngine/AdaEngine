import AdaECS
import AdaTransform
import box2d
import Math

/// One convex sweep hit; `distance` measures translation of the query pose's origin.
public struct ShapeCast2DHit: Sendable {
    public let entity: Entity
    public let shapeID: UInt64
    public let isSensor: Bool
    public let point: Vector2
    public let normal: Vector2
    public let distance: Float
    public let fraction: Float
    /// Initial overlaps have zero travel and no reliable contact normal.
    public var isInitialOverlap: Bool { fraction == 0 && normal == .zero }
}

@MainActor
extension PhysicsWorld2D {
    /// Sweeps a convex shape by translation, keeping its initial rotation/scale fixed.
    /// `.first` returns the nearest hit; `.all` is sorted by travel distance then shape ID.
    /// Initial overlaps are included with zero travel/normal. Zero motion performs an overlap query.
    /// Chain query volumes are unsupported, but the sweep can hit chains in the world.
    public func shapeCast(
        _ shape: Shape2DResource,
        from pose: Transform,
        to destination: Vector2,
        query: CollisionCastQueryType = .all,
        mask: CollisionGroup = .all,
        includeSensors: Bool = true,
        excluding entities: Set<Entity.ID> = []
    ) throws -> [ShapeCast2DHit] {
        let translation = destination - pose.position.xy
        let length = translation.squaredLength.squareRoot()
        guard destination.x.isFinite, destination.y.isFinite, length.isFinite else { throw Physics2DQueryError.invalidPose }
        if length == 0 {
            let hits = try overlap(shape, at: pose, mask: mask, includeSensors: includeSensors, excluding: entities)
                .map { ShapeCast2DHit(entity: $0.entity, shapeID: $0.shapeID, isSensor: $0.isSensor, point: pose.position.xy, normal: .zero, distance: 0, fraction: 0) }
                .sorted { $0.shapeID < $1.shapeID }
            return query == .first ? Array(hits.prefix(1)) : hits
        }
        var proxy = try NativeConvexQuery2D.make(shape, pose: pose)
        guard !mask.isEmpty else {
            return []
        }
        var collector = ShapeCast2DCollector(length: length, query: query, includeSensors: includeSensors, excluding: entities)
        var filter = b2DefaultQueryFilter()
        filter.categoryBits = UInt64.max
        filter.maskBits = mask.rawValue
        // Box2D copies neither pointer beyond this synchronous traversal.
        _ = unsafe withUnsafeMutablePointer(to: &collector) {
            unsafe b2World_CastShape(worldId, pose.position.xy.b2Position, &proxy, translation.b2Vec, filter, PhysicsWorld2D_ShapeCast, $0)
        }
        return collector.hits.sorted { $0.distance == $1.distance ? $0.shapeID < $1.shapeID : $0.distance < $1.distance }
    }
}

private struct ShapeCast2DCollector {
    let length: Float
    let query: CollisionCastQueryType
    let includeSensors: Bool
    let excluding: Set<Entity.ID>
    var hits: [ShapeCast2DHit] = []
}

private func PhysicsWorld2D_ShapeCast(
    _ id: b2ShapeId,
    _ point: b2Pos,
    _ normal: b2Vec2,
    _ fraction: Float,
    _ context: UnsafeMutableRawPointer?
) -> Float {
    let shape = BoxShape2D(shape: id)
    guard shape.isValid, let entity = shape.body?.entity, let context = unsafe context else {
        return -1
    }
    let collector = unsafe context.assumingMemoryBound(to: ShapeCast2DCollector.self)
    if unsafe collector.pointee.excluding.contains(entity.id) || (!collector.pointee.includeSensors && shape.isSensor) {
        return -1
    }
    let hit = unsafe ShapeCast2DHit(
        entity: entity,
        shapeID: b2StoreShapeId(id),
        isSensor: shape.isSensor,
        point: point.asVector2,
        normal: normal.asVector2,
        distance: collector.pointee.length * fraction,
        fraction: fraction
    )
    if unsafe collector.pointee.query == .first {
        if unsafe collector.pointee.hits.isEmpty { unsafe collector.pointee.hits.append(hit) } else { unsafe collector.pointee.hits[0] = hit }
        return fraction
    }
    unsafe collector.pointee.hits.append(hit)
    return 1
}
