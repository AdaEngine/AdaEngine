import AdaTransform
import box2d
import Math

/// Invalid poses and non-convex query shapes cannot be passed to native convex queries.
public enum Physics2DQueryError: Error, Equatable, Sendable {
    case invalidPose
    case invalidGeometry
    case unsupportedShape
}

enum NativeConvexQuery2D {
    static func make(_ resource: Shape2DResource, pose: Transform) throws -> b2ShapeProxy {
        let scale = pose.scale.xy
        let rotation = pose.rotation
        guard pose.position.x.isFinite, pose.position.y.isFinite, scale.x.isFinite, scale.y.isFinite,
            rotation.x.isFinite, rotation.y.isFinite, rotation.z.isFinite, rotation.w.isFinite else { throw Physics2DQueryError.invalidPose }
        let bodyRotation = b2MakeRot(rotation.angle2D.radians)
        let roundingScale = max(abs(scale.x), abs(scale.y))
        let points: [Vector2]
        let radius: Float
        switch resource.fixture {
        case let .circle(shape):
            points = [shape.offset]
            radius = shape.radius * abs(scale.x)
        case let .capsule(shape):
            points = [shape.start + shape.offset, shape.end + shape.offset]
            radius = shape.radius * roundingScale
        case let .box(shape):
            let x = shape.halfWidth
            let y = shape.halfHeight
            let cosine = Math.cos(shape.angle)
            let sine = Math.sin(shape.angle)
            let vertices: [Vector2] = [[-x, -y], [x, -y], [x, y], [-x, y]]
            points = vertices.map { Vector2(cosine * $0.x - sine * $0.y, sine * $0.x + cosine * $0.y) + shape.offset }
            radius = 0
        case let .polygon(shape):
            points = shape.verticies.map { $0 + shape.offset }
            radius = 0
        case let .roundedPolygon(shape):
            points = shape.vertices.map { $0 + shape.offset }
            radius = shape.radius * roundingScale
        case let .segment(shape):
            points = shape.points.map { $0 + shape.offset }
            radius = 0
        case .chain, .chainSegment:
            throw Physics2DQueryError.unsupportedShape
        }
        guard (1...Int(B2_MAX_POLYGON_VERTICES)).contains(points.count), radius.isFinite, radius >= 0 else {
            throw Physics2DQueryError.invalidGeometry
        }
        let native = points.map { b2RotateVector(bodyRotation, ($0 * scale).b2Vec) }
        guard native.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) else { throw Physics2DQueryError.invalidPose }
        if native.count >= 3 {
            var hull = unsafe native.withUnsafeBufferPointer { unsafe b2ComputeHull($0.baseAddress, Int32($0.count)) }
            guard hull.count >= 3 else { throw Physics2DQueryError.invalidGeometry }
            // Clang's imported tuple is the contiguous C b2Vec2[8] array. b2MakeProxy copies it.
            return unsafe withUnsafePointer(to: &hull.points) { tuple in
                unsafe tuple.withMemoryRebound(to: b2Vec2.self, capacity: Int(B2_MAX_POLYGON_VERTICES)) {
                    unsafe b2MakeProxy($0, hull.count, radius)
                }
            }
        }
        if native.count == 2 {
            let distance = (native[1].asVector2 - native[0].asVector2).squaredLength
            let slop = 0.005 * b2GetLengthUnitsPerMeter()
            guard distance.isFinite, distance > slop * slop else { throw Physics2DQueryError.invalidGeometry }
        }
        return unsafe native.withUnsafeBufferPointer { unsafe b2MakeProxy($0.baseAddress, Int32($0.count), radius) }
    }
}
