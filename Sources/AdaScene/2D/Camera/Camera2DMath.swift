import Foundation
import Math

/// Pure rules behind ``Camera2DController``, kept free of ECS so they can be checked directly.
enum Camera2DMath {
    /// Fraction of the remaining distance to cover this step. The same wall-clock time gives the same result at
    /// any frame rate: after `time` seconds about 63% of the distance is covered.
    static func smoothingFactor(deltaTime: Double, time: Float) -> Float {
        guard time.isFinite, time > 0 else { return 1 }
        guard deltaTime.isFinite, deltaTime > 0 else { return 0 }
        return Float(1 - exp(-deltaTime / Double(time)))
    }

    /// Moves `position` the least needed to bring `target` inside a rectangle of `deadZone` size centred on it.
    static func applyDeadZone(position: Vector2, target: Vector2, deadZone: Vector2) -> Vector2 {
        let half = Vector2(max(0, deadZone.x) / 2, max(0, deadZone.y) / 2)
        func axis(_ position: Float, _ target: Float, _ half: Float) -> Float {
            if target > position + half { return target - half }
            if target < position - half { return target + half }
            return position
        }
        return Vector2(axis(position.x, target.x, half.x), axis(position.y, target.y, half.y))
    }

    /// How far the visible area extends from the camera position on each side, in world units.
    struct ViewExtents: Equatable {
        var left: Float
        var right: Float
        var bottom: Float
        var top: Float

        init(viewportSize: Size, zoom: Float, viewportOrigin: Vector2) {
            let width = viewportSize.width / zoom
            let height = viewportSize.height / zoom
            self.left = width * viewportOrigin.x
            self.right = width * (1 - viewportOrigin.x)
            self.bottom = height * viewportOrigin.y
            self.top = height * (1 - viewportOrigin.y)
        }
    }

    /// Keeps the visible area inside `[limitMin, limitMax]`. An axis the view is larger than is centred on the limits.
    static func clamp(position: Vector2, extents: ViewExtents, limitMin: Vector2, limitMax: Vector2) -> Vector2 {
        func axis(_ position: Float, _ before: Float, _ after: Float, _ lower: Float, _ upper: Float) -> Float {
            if upper - lower <= before + after { return (lower + upper) / 2 + (before - after) / 2 }
            return min(max(position, lower + before), upper - after)
        }
        return Vector2(
            axis(position.x, extents.left, extents.right, limitMin.x, limitMax.x),
            axis(position.y, extents.bottom, extents.top, limitMin.y, limitMax.y)
        )
    }

    /// Camera shake driven by trauma in 0...1. Intensity is trauma squared, so small hits are subtle and large ones violent.
    /// The noise is a fixed function of time, which keeps playback reproducible.
    static func shake(trauma: Float, time: Double, frequency: Float, maxOffset: Vector2, maxRoll: Float) -> (offset: Vector2, roll: Float) {
        let clamped = min(max(trauma.isFinite ? trauma : 0, 0), 1)
        guard clamped > 0 else { return (.zero, 0) }
        let intensity = clamped * clamped
        let t = time * Double(max(frequency, 0))
        return (
            Vector2(maxOffset.x * intensity * noise(t, seed: 1), maxOffset.y * intensity * noise(t, seed: 2)),
            maxRoll * intensity * noise(t, seed: 3)
        )
    }

    /// Smooth value in -1...1 built from three sines of unrelated periods.
    static func noise(_ t: Double, seed: Double) -> Float {
        let slow: Double = Foundation.sin(t + seed * 12.9898)
        let medium: Double = 0.5 * Foundation.sin(t * 2.3 + seed * 78.233)
        let fast: Double = 0.25 * Foundation.sin(t * 4.1 + seed * 37.719)
        return Float((slow + medium + fast) / 1.75)
    }

    /// Rounds a position to whole screen pixels at the given zoom.
    static func snapToPixels(_ position: Vector2, zoom: Float) -> Vector2 {
        guard zoom.isFinite, zoom > 0 else { return position }
        return Vector2((position.x * zoom).rounded() / zoom, (position.y * zoom).rounded() / zoom)
    }
}
