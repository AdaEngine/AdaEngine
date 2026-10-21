import box2d
import Math

extension Shape2DResource {
    struct LineShape: Codable, Hashable, Sendable {
        let points: [Vector2]
        var isLoop = false
        var ghostStart: Vector2?
        var ghostEnd: Vector2?
        var offset: Vector2 = .zero

        private enum CodingKeys: CodingKey { case points, isLoop, ghostStart, ghostEnd, offset }

        init(points: [Vector2], isLoop: Bool = false, ghostStart: Vector2? = nil, ghostEnd: Vector2? = nil) {
            self.points = points
            self.isLoop = isLoop
            self.ghostStart = ghostStart
            self.ghostEnd = ghostEnd
        }

        init(from decoder: any Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            points = try values.decode([Vector2].self, forKey: .points)
            isLoop = try values.decodeIfPresent(Bool.self, forKey: .isLoop) ?? false
            ghostStart = try values.decodeIfPresent(Vector2.self, forKey: .ghostStart)
            ghostEnd = try values.decodeIfPresent(Vector2.self, forKey: .ghostEnd)
            offset = try values.decodeIfPresent(Vector2.self, forKey: .offset) ?? .zero
        }

        var leadingGhost: Vector2 { ghostStart ?? points[0] * 2 - points[1] }
        var trailingGhost: Vector2 { ghostEnd ?? points[points.count - 1] * 2 - points[points.count - 2] }
    }

    /// Creates a two-sided, zero-thickness segment. Endpoints must exceed native linear slop.
    public static func generateSegment(from start: Vector2, to end: Vector2) throws -> Shape2DResource {
        let shape = LineShape(points: [start, end])
        try Geometry2DValidation.line(shape, kind: .segment)
        return Shape2DResource(fixture: .segment(shape))
    }

    /// Creates a one-sided chain. Its front face is to the right of each directed edge.
    /// Do not repeat the first vertex for loops. Open-chain ghosts default to linear extrapolation.
    /// Chains have no native mass and are intended primarily for static terrain.
    public static func generateChain(
        points: [Vector2],
        isLoop: Bool = false,
        ghostStart: Vector2? = nil,
        ghostEnd: Vector2? = nil
    ) throws -> Shape2DResource {
        let shape = LineShape(points: points, isLoop: isLoop, ghostStart: ghostStart, ghostEnd: ghostEnd)
        try Geometry2DValidation.line(shape, kind: .chain)
        return Shape2DResource(fixture: .chain(shape))
    }

    /// Creates a loose one-sided chain segment; ghost vertices suppress internal-edge collisions.
    /// Unlike an owned chain this has no parent native chain ID.
    public static func generateChainSegment(
        from start: Vector2,
        to end: Vector2,
        ghostStart: Vector2? = nil,
        ghostEnd: Vector2? = nil
    ) throws -> Shape2DResource {
        let shape = LineShape(points: [start, end], ghostStart: ghostStart, ghostEnd: ghostEnd)
        try Geometry2DValidation.line(shape, kind: .loose)
        return Shape2DResource(fixture: .chainSegment(shape))
    }
}

extension Geometry2DValidation {
    enum LineKind: Equatable { case segment, chain, loose }

    static func line(_ shape: Shape2DResource.LineShape, kind: LineKind) throws {
        let points = shape.points
        guard points.count >= (shape.isLoop ? 3 : 2), points.count <= Int(Int32.max),
            kind == .chain || (points.count == 2 && !shape.isLoop) else { throw Shape2DGeometryError.invalidChain }
        try point(shape.offset)
        try points.forEach(point)
        let slop = 0.005 * b2GetLengthUnitsPerMeter()
        for first in points.indices {
            for second in (first + 1)..<points.count {
                let distance = (points[first] - points[second]).squaredLength
                guard distance.isFinite, distance > slop * slop else { throw Shape2DGeometryError.invalidChain }
            }
        }
        if !shape.isLoop && kind != .segment {
            try point(shape.leadingGhost)
            try point(shape.trailingGhost)
            guard (shape.leadingGhost - points[0]).squaredLength > slop * slop,
                (shape.trailingGhost - points[points.count - 1]).squaredLength > slop * slop else { throw Shape2DGeometryError.invalidChain }
        }
        let count = shape.isLoop ? points.count : points.count - 1
        for first in 0..<count {
            for second in (first + 2)..<max(first + 2, count) {
                if shape.isLoop && first == 0 && second == count - 1 { continue }
                if intersects(points[first], points[(first + 1) % points.count], points[second], points[(second + 1) % points.count]) {
                    throw Shape2DGeometryError.invalidChain
                }
            }
        }
    }

    private static func intersects(_ a: Vector2, _ b: Vector2, _ c: Vector2, _ d: Vector2) -> Bool {
        func cross(_ x: Vector2, _ y: Vector2) -> Float { x.x * y.y - x.y * y.x }
        guard max(min(a.x, b.x), min(c.x, d.x)) <= min(max(a.x, b.x), max(c.x, d.x)),
            max(min(a.y, b.y), min(c.y, d.y)) <= min(max(a.y, b.y), max(c.y, d.y)) else {
            return false
        }
        let first = cross(b - a, c - a)
        let second = cross(b - a, d - a)
        let third = cross(d - c, a - c)
        let fourth = cross(d - c, b - c)
        return (first == 0 || second == 0 || (first < 0) != (second < 0))
            && (third == 0 || fourth == 0 || (third < 0) != (fourth < 0))
    }
}
