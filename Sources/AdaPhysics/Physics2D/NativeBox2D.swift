import box2d
import Math

/// Boxes are analytically convex. Hull welding would erase valid thin boxes.
enum NativeBox2D {
    static func make(_ shape: Shape2DResource.BoxShape, scale: Vector2) -> b2Polygon? {
        guard shape.halfWidth.isFinite, shape.halfHeight.isFinite, shape.halfWidth > 0, shape.halfHeight > 0,
            shape.angle.isFinite, scale.x.isFinite, scale.y.isFinite, scale.x != 0, scale.y != 0 else {
            return nil
        }
        let rotation = b2MakeRot(shape.angle)
        let x = shape.halfWidth
        let y = shape.halfHeight
        var vertices: [b2Vec2] = [[-x, -y], [x, -y], [x, y], [-x, y]].map { (point: Vector2) in
            ((b2RotateVector(rotation, point.b2Vec).asVector2 + shape.offset) * scale).b2Vec
        }
        guard vertices.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) else {
            return nil
        }
        if (scale.x < 0) != (scale.y < 0) { vertices.reverse() }
        var normals: [b2Vec2] = []
        for index in 0..<4 {
            let edge = vertices[(index + 1) % 4].asVector2 - vertices[index].asVector2
            let length = edge.squaredLength.squareRoot()
            guard length.isFinite, length > Float.ulpOfOne else {
            return nil
        }
            normals.append(b2Vec2(x: edge.y / length, y: -edge.x / length))
        }
        var polygon = b2MakeBox(x, y)
        unsafe withUnsafeMutablePointer(to: &polygon.vertices) { tuple in
            unsafe tuple.withMemoryRebound(to: b2Vec2.self, capacity: Int(B2_MAX_POLYGON_VERTICES)) { buffer in
                for index in 0..<4 { unsafe buffer[index] = vertices[index] }
            }
        }
        unsafe withUnsafeMutablePointer(to: &polygon.normals) { tuple in
            unsafe tuple.withMemoryRebound(to: b2Vec2.self, capacity: Int(B2_MAX_POLYGON_VERTICES)) { buffer in
                for index in 0..<4 { unsafe buffer[index] = normals[index] }
            }
        }
        polygon.centroid = (shape.offset * scale).b2Vec
        return polygon
    }
}
