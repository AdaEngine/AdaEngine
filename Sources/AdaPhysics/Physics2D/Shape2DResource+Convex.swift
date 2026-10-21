import box2d
import Math

/// Invalid geometry is rejected before reaching Box2D's native constructors.
public enum Shape2DGeometryError: Error, Equatable, Sendable {
    case nonFiniteGeometry
    case invalidDimensions
    case invalidRadius
    case invalidPolygon
    case degenerateCapsule
}

extension Shape2DResource {
    struct CapsuleShape: Codable, Hashable, Sendable {
        let start: Vector2
        let end: Vector2
        let radius: Float
        var offset: Vector2 = .zero

        private enum CodingKeys: CodingKey { case start, end, radius, offset }

        init(start: Vector2, end: Vector2, radius: Float) throws {
            try Geometry2DValidation.capsule(start: start, end: end, radius: radius)
            self.start = start
            self.end = end
            self.radius = radius
        }

        init(from decoder: any Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            try self.init(
                start: values.decode(Vector2.self, forKey: .start),
                end: values.decode(Vector2.self, forKey: .end),
                radius: values.decode(Float.self, forKey: .radius)
            )
            offset = try values.decodeIfPresent(Vector2.self, forKey: .offset) ?? .zero
            try Geometry2DValidation.point(offset)
        }
    }

    struct RoundedPolygonShape: Codable, Hashable, Sendable {
        let vertices: [Vector2]
        let radius: Float
        var offset: Vector2 = .zero

        private enum CodingKeys: CodingKey { case vertices, radius, offset }

        init(vertices: [Vector2], radius: Float) throws {
            try Geometry2DValidation.radius(radius)
            try Geometry2DValidation.polygon(vertices)
            self.vertices = vertices
            self.radius = radius
        }

        init(from decoder: any Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            try self.init(vertices: values.decode([Vector2].self, forKey: .vertices), radius: values.decode(Float.self, forKey: .radius))
            offset = try values.decodeIfPresent(Vector2.self, forKey: .offset) ?? .zero
            try Geometry2DValidation.point(offset)
        }
    }

    /// Creates a capsule between two local cap centers. `radius` is in world units before scale.
    /// Cap centers must be separated by more than Box2D's linear slop (0.005 meters by default).
    public static func generateCapsule(from start: Vector2, to end: Vector2, radius: Float) throws -> Shape2DResource {
        Shape2DResource(fixture: .capsule(try CapsuleShape(start: start, end: end, radius: radius)))
    }

    /// Creates a rounded box whose width and height include the corner arcs.
    /// The radius must be positive and smaller than half the smaller outer dimension.
    /// Angle is counterclockwise in radians. Rounding remains circular under nonuniform scale.
    public static func generateRoundedBox(
        width: Float,
        height: Float,
        radius: Float,
        center: Vector2 = .zero,
        angle: Float = 0
    ) throws -> Shape2DResource {
        guard width.isFinite, height.isFinite, angle.isFinite else { throw Shape2DGeometryError.nonFiniteGeometry }
        guard width > 0, height > 0 else { throw Shape2DGeometryError.invalidDimensions }
        try Geometry2DValidation.radius(radius)
        try Geometry2DValidation.point(center)
        guard radius < min(width, height) / 2 else { throw Shape2DGeometryError.invalidRadius }
        let x = width / 2 - radius
        let y = height / 2 - radius
        let cosine = Math.cos(angle)
        let sine = Math.sin(angle)
        let vertices: [Vector2] = [[-x, -y], [x, -y], [x, y], [-x, y]]
        var shape = try RoundedPolygonShape(vertices: vertices.map {
            Vector2(cosine * $0.x - sine * $0.y, sine * $0.x + cosine * $0.y)
        }, radius: radius)
        shape.offset = center
        return Shape2DResource(fixture: .roundedPolygon(shape))
    }

    /// Creates the Minkowski sum of a convex core and a disk of `radius`.
    /// Supply 3...8 convex points; their winding is normalized by Box2D.
    /// Radius expands beyond the supplied core vertices, unlike the outer-size rounded-box factory.
    public static func generateRoundedPolygon(vertices: [Vector2], radius: Float) throws -> Shape2DResource {
        Shape2DResource(fixture: .roundedPolygon(try RoundedPolygonShape(vertices: vertices, radius: radius)))
    }
}

private enum Geometry2DValidation {
    static func point(_ value: Vector2) throws {
        guard value.x.isFinite, value.y.isFinite else { throw Shape2DGeometryError.nonFiniteGeometry }
    }

    static func radius(_ radius: Float) throws {
        guard radius.isFinite, radius > 0 else { throw Shape2DGeometryError.invalidRadius }
    }

    static func capsule(start: Vector2, end: Vector2, radius: Float) throws {
        try point(start)
        try point(end)
        try self.radius(radius)
        let separation = (end - start).squaredLength
        let slop = 0.005 * b2GetLengthUnitsPerMeter()
        guard separation.isFinite, separation > slop * slop else { throw Shape2DGeometryError.degenerateCapsule }
    }

    static func polygon(_ vertices: [Vector2]) throws {
        guard (3...Int(B2_MAX_POLYGON_VERTICES)).contains(vertices.count) else { throw Shape2DGeometryError.invalidPolygon }
        try vertices.forEach(point)
        let native = vertices.map(\.b2Vec)
        var hull = unsafe native.withUnsafeBufferPointer { buffer in
            unsafe b2ComputeHull(buffer.baseAddress, Int32(buffer.count))
        }
        guard Int(hull.count) == vertices.count, unsafe b2ValidateHull(&hull) else { throw Shape2DGeometryError.invalidPolygon }
    }
}
