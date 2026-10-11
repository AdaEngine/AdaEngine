//
//  GlassBackgroundCapture.swift
//  AdaEngine
//

import AdaCorePipelines
import AdaECS
import AdaRender
import Math

/// Holds the captured background texture used by the glass effect.
///
/// Updated inside ``UIRenderNode`` immediately before drawing each UI batch that contains
/// glass: the render pass is ended, the camera main target is blitted into this texture on
/// the **same** command buffer, then the UI pass continues with ``loadAction`` so prior
/// pixels (ECS, `.background()`, etc.) stay in the main target. Glass quads sample this
/// texture for blur and refraction.
///
/// Rendering owns mutation of this resource during the draw pass; the unchecked
/// conformance mirrors other render resources passed through ECS storage.
public final class GlassBackgroundTexture: Resource, @unchecked Sendable {
    public var texture: RenderTexture?

    public init() {}
}

/// Conservative pixel bounds of every background sample made by a glass batch.
/// Keep the full-size texture/UVs, but copy only this region before the batch.
enum GlassBackgroundCapture {
    static func region(
        vertices: [GlassVertexData], viewport: Rect, scaleFactor: Float, textureSize: SizeInt
    ) -> Rect {
        let full = Rect(x: 0, y: 0, width: Float(textureSize.width), height: Float(textureSize.height))
        guard !vertices.isEmpty, scaleFactor.isFinite, scaleFactor > 0 else {
            return full
        }
        var minX = Float.infinity
        var minY = Float.infinity
        var maxX = -Float.infinity
        var maxY = -Float.infinity
        for vertex in vertices {
            let position = vertex.position
            let halfSize = vertex.glassInfo0
            let optical = vertex.glassParams1
            let sampleScale = max(halfSize.z, 1)
            let minSide = max(0, min(halfSize.x, halfSize.y))
            // Shader edgeFactor <= 2. Include blur footprint, refraction,
            // dispersion, magnification and bilinear filtering at the boundary.
            let blur = max(vertex.glassParams0.x * sampleScale, 4)
            let refraction = 2 * max(optical.z - 1, 0) * 5 * minSide * 0.2
            let dispersion = 8 * min(max(optical.w, 0), 1)
            let magnification = max(optical.y, 0) * 0.0015 * minSide
            let padding = blur + (refraction + dispersion + magnification) * sampleScale + 2
            let x = viewport.minX + position.x * scaleFactor
            let y = viewport.minY - position.y * scaleFactor
            guard position.w == 1, x.isFinite, y.isFinite, padding.isFinite else {
                return full
            }
            minX = min(minX, x - padding)
            minY = min(minY, y - padding)
            maxX = max(maxX, x + padding)
            maxY = max(maxY, y + padding)
        }
        let lowerX = max(minX.rounded(.down), 0)
        let lowerY = max(minY.rounded(.down), 0)
        let upperX = min(maxX.rounded(.up), full.width)
        let upperY = min(maxY.rounded(.up), full.height)
        guard upperX > lowerX, upperY > lowerY else {
            return full
        }
        return Rect(x: lowerX, y: lowerY, width: max(upperX - lowerX, 0), height: max(upperY - lowerY, 0))
    }
}
