import AdaRender
import Math

/// Analytic light projection. Geometry is computed in 3D and returned in unfolded playfield coordinates.
public enum ShadowProjection {
    public static func polygons(bridge: ShadowBridge, pose: FoldPose, caster: FoldAttachment? = nil) -> [ShadowPolygon] {
        let attachment = caster ?? bridge.caster
        let p = attachment.position
        let lamp = pose.worldPoint(bridge.lamp.position, surface: bridge.lamp.surface)
        let corners = [Vector3(p.x - bridge.width / 2, p.y, p.z), Vector3(p.x + bridge.width / 2, p.y, p.z),
                       Vector3(p.x + bridge.width / 2, p.y - bridge.height, p.z), Vector3(p.x - bridge.width / 2, p.y - bridge.height, p.z)]
        return [FoldSurface.innerLeft, .innerRight].compactMap { surface in
            let offset: Float = surface == .innerRight ? 400 : 0
            let projected = corners.compactMap { point -> Vector2? in
                guard let result = pose.project(light: lamp, point: pose.worldPoint(point, surface: attachment.surface), onto: surface) else { return nil }
                return Vector2(result.x + offset, result.y)
            }
            guard projected.count == corners.count else { return nil }
            let bounds = bridge.receivingBounds
            let x0 = max(offset, bounds.minX), x1 = min(offset + 400, bounds.maxX)
            guard x1 > x0 else { return nil }
            let points = clipped(projected, to: Rect(x: x0, y: bounds.minY, width: x1 - x0, height: bounds.height))
            guard points.count >= 3 else { return nil }
            return ShadowPolygon(id: bridge.id + "." + surface.rawValue, points: points)
        }
    }

    private static func clipped(_ input: [Vector2], to rect: Rect) -> [Vector2] {
        var points = input
        for (axis, bound, greater) in [(0, rect.minX, true), (0, rect.maxX, false), (1, rect.minY, true), (1, rect.maxY, false)] {
            guard let last = points.last else { return [] }
            var result: [Vector2] = []
            var previous = last
            func value(_ p: Vector2) -> Float { axis == 0 ? p.x : p.y }
            func inside(_ p: Vector2) -> Bool { greater ? value(p) >= bound : value(p) <= bound }
            for current in points {
                if inside(previous) != inside(current) {
                    let t = (bound - value(previous)) / (value(current) - value(previous))
                    result.append(previous + (current - previous) * t)
                }
                if inside(current) { result.append(current) }
                previous = current
            }
            points = result
        }
        return points
    }
}
