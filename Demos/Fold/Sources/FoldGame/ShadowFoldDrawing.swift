import AdaRender
import AdaScene
import AdaUI
import AdaUtils
import Foundation
import Math

struct ShadowScreenMapping {
    let size: Size
    let pose: FoldPose
    var scale: Float {
        if pose.showsOuter { return max(0.1, min((size.width - 70) / 440, (size.height - 260) / 520)) }
        let half: Float = (180 - pose.playableAngle) * .pi / 360
        let perspective: Float = 1100 / (1100 - Math.sin(half) * 400)
        return max(0.1, min((size.width - 70) / (800 * Math.cos(half) * perspective + 40), (size.height - 260) / (480 * perspective + 40)))
    }
    var center: Vector2 { Vector2(size.width / 2, 90 + (size.height - 260) / 2) }

    func point(_ p: Vector3, surface: FoldSurface) -> Vector2 {
        let w = pose.worldPoint(p, surface: surface)
        let angle: Float = (180 - pose.playableAngle) * .pi / 360
        let x = Math.cos(angle) * (w.x - 400) + Math.sin(angle) * w.z
        let z = -Math.sin(angle) * (w.x - 400) + Math.cos(angle) * w.z
        let perspective = 1100 / max(500, 1100 - z)
        return center + Vector2(x, -(w.y - 240)) * perspective * scale
    }
    func flat(_ p: Vector2) -> Vector2 {
        point(Vector3(p.x < 400 ? p.x : p.x - 400, p.y, 0), surface: p.x < 400 ? .innerLeft : .innerRight)
    }
    func outer(_ p: Vector2) -> Vector2 { center + Vector2(p.x - 200, -(p.y - 240)) * scale }
    func outerLocal(_ p: Vector2) -> Vector2 { Vector2((p.x - center.x) / scale + 200, -(p.y - center.y) / scale + 240) }
}

extension ShadowFoldHost {
    func drawGame(_ game: ShadowSimulation, in rect: Rect, context: UIGraphicsContext) {
        let map = ShadowScreenMapping(size: rect.size, pose: game.pose)
        if game.pose.showsOuter {
            context.drawRect(rect, color: Color.fromHex(0x182639))
            fill([Vector2(0, 0), Vector2(400, 0), Vector2(400, 480), Vector2(0, 480)].map(map.outer), color: 0x344762, context: context)
            let portal = map.outer(game.level.portal)
            context.drawEllipse(in: Rect(x: portal.x - 44 * map.scale, y: portal.y - 44 * map.scale, width: 88 * map.scale, height: 88 * map.scale),
                                color: Color.fromHex(0x8ED7CE), thickness: 0.065)
            context.drawEllipse(in: Rect(x: portal.x - 34 * map.scale, y: portal.y - 34 * map.scale, width: 68 * map.scale, height: 68 * map.scale),
                                color: Color.fromHex(0x75AFAE), thickness: 0.025)
            if !game.transferred {
                let p = Vector2(game.plate.position.x, game.plate.position.y)
                fill([p + Vector2(-32, -10), p + Vector2(32, -10), p + Vector2(32, 10), p + Vector2(-32, 10)].map(map.outer), color: 0xF4BE72, context: context)
            }
            if game.transferFlash > 0 {
                context.drawEllipse(in: Rect(x: portal.x - 55, y: portal.y - 55, width: 110, height: 110), color: Color.fromHex(0xFFF0BD).opacity(game.transferFlash * 0.6))
            }
            return
        }
        for surface in [FoldSurface.innerLeft, .innerRight] {
            for y in stride(from: Float(25), to: 480, by: 32) {
                stroke(start: map.point(Vector3(12, y, 0), surface: surface), end: map.point(Vector3(388, y, 0), surface: surface),
                                 width: 0.6, color: Color.fromHex(0xB6AD9C).opacity(0.3), context: context)
            }
        }
        for polygon in game.polygons {
            fill(polygon.points.map(map.flat), color: 0x34415B, context: context)
        }
        for solid in game.level.platforms {
            let r = solid.rect
            fill([Vector2(r.minX, r.minY), Vector2(r.maxX, r.minY), Vector2(r.maxX, r.maxY), Vector2(r.minX, r.maxY)].map(map.flat), color: 0x34415B, context: context)
            stroke(start: map.flat(Vector2(r.minX, r.maxY)), end: map.flat(Vector2(r.maxX, r.maxY)), width: 4, color: Color.fromHex(0xAA9778), context: context)
        }
        for (index, point) in game.level.checkpoints.enumerated() {
            let p = map.flat(point + Vector2(0, 8))
            context.drawEllipse(in: Rect(x: p.x - 4, y: p.y - 4, width: 8, height: 8), color: Color.fromHex(index < game.checkpoint ? 0x65B7A8 : 0xC3B592))
        }
        // Light and blocker are shown at their actual attachments, making the optical cause visible.
        for bridge in game.level.bridges where bridge.minimumCheckpoint == min(game.checkpoint, 2) {
            let lamp = map.point(bridge.lamp.position, surface: bridge.lamp.surface)
            context.drawEllipse(in: Rect(x: lamp.x - 17, y: lamp.y - 17, width: 34, height: 34), color: Color.fromHex(0xF2BC6C).opacity(0.18))
            context.drawEllipse(in: Rect(x: lamp.x - 6, y: lamp.y - 6, width: 12, height: 12), color: Color.fromHex(0xFFD78C))
            if !bridge.requiresTransferredItem || game.transferred {
                let attachment = bridge.requiresTransferredItem ? game.plate : bridge.caster
                let p = attachment.position
                let corners = [Vector3(p.x - bridge.width / 2, p.y, p.z), Vector3(p.x + bridge.width / 2, p.y, p.z),
                               Vector3(p.x + bridge.width / 2, p.y - bridge.height, p.z), Vector3(p.x - bridge.width / 2, p.y - bridge.height, p.z)]
                fill(corners.map { map.point($0, surface: attachment.surface) }, color: 0xBD854D, context: context)
                let casterCenter = map.point(p, surface: attachment.surface)
                stroke(start: lamp, end: casterCenter, width: 1, color: Color.fromHex(0xD6A461).opacity(0.45), context: context)
            }
        }
        let p = game.player
        // A small paper traveller: coat, head and a dark visor retain a readable silhouette.
        fill([p + Vector2(-9, 1), p + Vector2(10, 1), p + Vector2(7, 19), p + Vector2(-5, 21)].map(map.flat), color: 0x6EA79E, context: context)
        fill([p + Vector2(-6, 18), p + Vector2(7, 18), p + Vector2(7, 30), p + Vector2(-6, 30)].map(map.flat), color: 0xFFF8E8, context: context)
        let eye = map.flat(p + Vector2(3, 25))
        context.drawEllipse(in: Rect(x: eye.x - 1.5, y: eye.y - 1.5, width: 3, height: 3), color: Color.fromHex(0x253B4A))
        let door = Vector2(game.level.exitX + 12, 100)
        fill([door, door + Vector2(32, 0), door + Vector2(32, 58), door + Vector2(0, 58)].map(map.flat), color: game.completed ? 0x7EBAA3 : 0xBFA979, context: context)
        let handleY = rect.height - 145
        stroke(start: Vector2(rect.width / 2 - 160, handleY), end: Vector2(rect.width / 2 + 160, handleY), width: 3, color: Color.fromHex(0x637F8E), context: context)
        let handleX = rect.width / 2 - 160 + (game.pose.playableAngle - 45) / 135 * 320
        context.drawEllipse(in: Rect(x: handleX - 9, y: handleY - 9, width: 18, height: 18), color: Color.fromHex(0xE9CD96))
    }

    private func stroke(start: Vector2, end: Vector2, width: Float, color: Color, context: UIGraphicsContext) {
        let delta = end - start
        let length = (delta.x * delta.x + delta.y * delta.y).squareRoot()
        guard length > 0.001 else { return }
        let normal = Vector2(-delta.y, delta.x) * (width / (2 * length))
        var path = Path()
        path.move(to: start + normal); path.addLine(to: end + normal)
        path.addLine(to: end - normal); path.addLine(to: start - normal); path.closeSubpath()
        context.fill(path, with: color)
    }

    private func fill(_ points: [Vector2], color: Int, context: UIGraphicsContext) {
        guard let first = points.first else { return }
        var path = Path()
        path.move(to: first)
        for p in points.dropFirst() { path.addLine(to: p) }
        path.closeSubpath()
        context.fill(path, with: Color.fromHex(Int(color)))
    }
}
