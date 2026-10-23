import AdaUtils
import Math

extension ExtractedPhysicsDebugShapes {
    public mutating func addLine(from start: Vector2, to end: Vector2, color: Color) {
        lines.append(.init(start: start, end: end, color: color))
    }
    public mutating func addCircle(at center: Vector2, radius: Float, color: Color) {
        guard radius.isFinite, radius > 0 else {
            return
        }
        circles.append(.init(center: center, radius: radius, color: color))
    }
    /// Adds an upright or oriented capsule outline in world units, including virtual query volumes.
    public mutating func addCapsule(from start: Vector2, to end: Vector2, radius: Float, color: Color) {
        let delta = end - start
        let length = delta.squaredLength.squareRoot()
        guard radius.isFinite, radius > 0, length.isFinite else {
            return
        }
        guard length > 0 else {
            addCircle(at: start, radius: radius, color: color)
            return
        }
        let normal = Vector2(-delta.y, delta.x) / length
        addLine(from: start + normal * radius, to: end + normal * radius, color: color)
        addLine(from: start - normal * radius, to: end - normal * radius, color: color)
        let angle = Math.atan2(normal.y, normal.x)
        for (center, initial) in [(end, angle), (start, angle + .pi)] {
            for index in 0..<12 {
                let a = initial - .pi * Float(index) / 12
                let b = initial - .pi * Float(index + 1) / 12
                addLine(
                    from: center + Vector2(Math.cos(a), Math.sin(a)) * radius,
                    to: center + Vector2(Math.cos(b), Math.sin(b)) * radius,
                    color: color
                )
            }
        }
    }
}
