import AdaECS
import box2d
import Math

struct CharacterGround2D {
    let entity: Entity.ID
    let body: b2BodyId
    let normal: Vector2
    let point: Vector2
}

@MainActor
final class CharacterRuntime2D {
    weak var world: PhysicsWorld2D?
    let owner: Entity.ID?
    let radius: Float
    let height: Float
    let mode: CharacterController2DMode
    var body: Body2D?
    var shapeID = b2_nullShapeId
    var airAnchor = b2_nullBodyId
    var mover = b2_nullJointId
    var pogo = b2_nullJointId
    var lastDeltaTime: Float = 1.0 / 60
    var visualRotation: Quat?
    var planes: [b2CollisionPlane] = []
    var contacts: [CharacterGround2D] = []

    init(world: PhysicsWorld2D, owner: Entity.ID?, settings: CharacterController2DSettings, mode: CharacterController2DMode = .query) {
        self.world = world; self.owner = owner; radius = settings.radius; height = settings.height; self.mode = mode
    }

    func collide(position: Vector2, capsule: b2Capsule, filter: b2QueryFilter, horizontal: Float, minimumNormal: Float) {
        var collector = CharacterPlaneCollector2D(owner: owner, horizontal: horizontal, minimumNormal: minimumNormal, origin: world?.coordinateOrigin ?? .zero)
        swap(&collector.planes, &planes)
        swap(&collector.contacts, &contacts)
        collector.planes.removeAll(keepingCapacity: true)
        collector.contacts.removeAll(keepingCapacity: true)
        var capsule = capsule
        // Match the solver's linear slop, so a sweep hit is always inside the plane query.
        capsule.radius += 0.005 * b2GetLengthUnitsPerMeter()
        if let world {
            unsafe withUnsafeMutablePointer(to: &collector) {
                unsafe b2World_CollideMover(world.worldId, world.nativePosition(position), &capsule, filter, Character2D_Plane, $0)
            }
        }
        swap(&collector.planes, &planes)
        swap(&collector.contacts, &contacts)
    }

    func ground(position: Vector2, minimumNormal: Float) -> CharacterGround2D? {
        var result: CharacterGround2D?
        for contact in contacts where contact.normal.y >= minimumNormal && contact.point.y <= position.y + height * 0.5 {
            if result == nil || contact.normal.y > (result?.normal.y ?? 0) { result = contact }
        }
        return result
    }
}

private struct CharacterPlaneCollector2D {
    let owner: Entity.ID?
    let horizontal: Float
    let minimumNormal: Float
    let origin: PhysicsPosition2D
    var planes: [b2CollisionPlane] = []
    var contacts: [CharacterGround2D] = []
}

private func Character2D_Plane(_ id: b2ShapeId, _ result: UnsafePointer<b2PlaneResult>?, _ context: UnsafeMutableRawPointer?) -> Bool {
    let shape = BoxShape2D(shape: id)
    guard shape.isValid, !shape.isSensor, let entity = shape.body?.entity, let result = unsafe result, let context = unsafe context else {
        return true
    }
    let collector = unsafe context.assumingMemoryBound(to: CharacterPlaneCollector2D.self)
    guard unsafe collector.pointee.owner != entity.id else {
        return true
    }
    let hit = unsafe result.pointee
    let normal = hit.plane.normal.asVector2
    if shape.type == b2_chainSegmentShape {
        // Native CollideMover treats chains as two-sided segments; retain the authored front.
        let line = b2Shape_GetChainSegment(id).segment
        let edge = line.point2.asVector2 - line.point1.asVector2
        let front = b2RotateVector(b2Body_GetRotation(shape.bodyId), b2Vec2(x: edge.y, y: -edge.x))
        if normal.x * front.x + normal.y * front.y <= 0 {
            return true
        }
    }
    let radius: Float
    switch shape.type {
    case b2_circleShape: radius = b2Shape_GetCircle(id).radius
    case b2_capsuleShape: radius = b2Shape_GetCapsule(id).radius
    case b2_polygonShape: radius = b2Shape_GetPolygon(id).radius
    default: radius = 0
    }
    // Box2D 3.2 shape.c leaves result.point in body-local core geometry; only its normal is rotated.
    let point = unsafe PhysicsPosition2D(b2Body_GetWorldPoint(shape.bodyId, hit.point)).displacement(from: collector.pointee.origin) + normal * radius
    unsafe collector.pointee.contacts.append(CharacterGround2D(entity: entity.id, body: shape.bodyId, normal: normal, point: point))
    unsafe collector.pointee.planes.append(b2CollisionPlane(plane: hit.plane, pushLimit: .greatestFiniteMagnitude, push: 0, clipVelocity: true))
    if unsafe normal.y > 0 && normal.y < collector.pointee.minimumNormal && normal.x * collector.pointee.horizontal < 0 {
        let plane = b2Plane(normal: b2Vec2(x: normal.x < 0 ? -1 : 1, y: 0), offset: hit.plane.offset / abs(normal.x))
        unsafe collector.pointee.planes.append(b2CollisionPlane(plane: plane, pushLimit: .greatestFiniteMagnitude, push: 0, clipVelocity: true))
    }
    return true
}

struct CharacterSweep2D {
    let owner: Entity.ID?
    let origin: PhysicsPosition2D
    var fraction: Float = 1
    var hit: CharacterGround2D?
}

@MainActor
extension PhysicsWorld2D {
    func castCharacter(position: Vector2, capsule: b2Capsule, delta: Vector2, filter: b2QueryFilter, owner: Entity.ID?) -> CharacterSweep2D {
        var collector = CharacterSweep2D(owner: owner, origin: coordinateOrigin)
        var points = (capsule.center1, capsule.center2)
        var proxy = unsafe withUnsafePointer(to: &points) { tuple in
            unsafe tuple.withMemoryRebound(to: b2Vec2.self, capacity: 2) { unsafe b2MakeProxy($0, 2, capsule.radius) }
        }
        _ = unsafe withUnsafeMutablePointer(to: &collector) {
            unsafe b2World_CastShape(worldId, nativePosition(position), &proxy, delta.b2Vec, filter, Character2D_Cast, $0)
        }
        return collector
    }
}

private func Character2D_Cast(_ id: b2ShapeId, _ point: b2Pos, _ normal: b2Vec2, _ fraction: Float, _ context: UnsafeMutableRawPointer?) -> Float {
    let shape = BoxShape2D(shape: id)
    guard fraction > 0, shape.isValid, !shape.isSensor, let entity = shape.body?.entity, let context = unsafe context else {
        return -1
    }
    let collector = unsafe context.assumingMemoryBound(to: CharacterSweep2D.self)
    guard unsafe collector.pointee.owner != entity.id else {
        return -1
    }
    unsafe collector.pointee.fraction = fraction
    let position = unsafe PhysicsPosition2D(point).displacement(from: collector.pointee.origin)
    unsafe collector.pointee.hit = CharacterGround2D(entity: entity.id, body: shape.bodyId, normal: normal.asVector2, point: position)
    return fraction
}
