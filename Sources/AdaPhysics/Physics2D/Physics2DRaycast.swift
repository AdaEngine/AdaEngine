import AdaECS
import box2d
import Math

// MARK: - b2RaycastCallback

/// A hit result of a collision cast.
public struct Raycast2DHit {
    /// The entity that was hit.
    public let entity: Entity

    /// The point of the hit.
    public let point: Vector2

    /// The normal of the hit.
    public let normal: Vector2

    /// The distance from the ray origin to the hit, or the convex shape travel distance.
    public let distance: Float
}

struct Raycast2DCollector {
    let length: Float
    let query: CollisionCastQueryType
    let origin: PhysicsPosition2D
    var results: [Raycast2DHit] = []
}

func PhysicsWorld2D_Raycast(
    _ shapeId: b2ShapeId,
    _ point: b2Pos,
    _ normal: b2Vec2,
    _ fraction: Float,
    _ context: UnsafeMutableRawPointer?
) -> Float {
    // Box2D reports an initial overlap with a zero fraction and zero normal.
    guard fraction != 0 || normal.x != 0 || normal.y != 0 else {
        return -1
    }
    let shape = BoxShape2D(shape: shapeId)
    guard shape.isValid, let entity = shape.body?.entity, let context = unsafe context else {
        return -1
    }
    let collector = unsafe context.assumingMemoryBound(to: Raycast2DCollector.self)
    let result = unsafe Raycast2DHit(
        entity: entity,
        point: PhysicsPosition2D(point).displacement(from: collector.pointee.origin),
        normal: normal.asVector2,
        distance: collector.pointee.length * fraction
    )
    if unsafe collector.pointee.query == .first {
        unsafe collector.pointee.results = [result]
        return fraction
    }
    unsafe collector.pointee.results.append(result)
    return 1
}
