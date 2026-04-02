//
//  GlassBackgroundCapture.swift
//  AdaEngine
//

import AdaECS
import AdaRender
import Math

/// Holds the captured background texture used by the glass effect.
///
/// Updated each frame before the UI render pass by `GlassBackgroundCaptureNode`.
/// Glass quads sample from this texture to produce the blurred background effect.
public final class GlassBackgroundTexture: Resource, @unchecked Sendable {
    public var texture: RenderTexture?

    public init() {}
}

/// Render node that copies the main scene texture into the glass background texture.
///
/// Must run after `Main2DRenderNode` and before `UIRenderNode` so that
/// glass elements can sample the fully-rendered scene without UI overdraw.
public struct GlassBackgroundCaptureNode: RenderNode {

    @Query<Entity, Camera, RenderViewTarget>
    private var query

    @ResMut<GlassBackgroundTexture>
    private var glassBackground

    public init() {}

    public func update(from world: World) {
        query.update(from: world)
        _glassBackground.update(from: world)
    }

    public func execute(
        context: inout Context,
        renderContext: RenderContext
    ) async throws -> [RenderSlotValue] {
        guard let view = context.viewEntity else {
            return []
        }

        try query.forEach { entity, _, target in
            if entity != view {
                return
            }

            guard let mainTexture = target.mainTexture else {
                return
            }

            let texWidth = mainTexture.width
            let texHeight = mainTexture.height

            // Lazily create or resize the glass background texture
            if glassBackground.texture == nil
                || glassBackground.texture?.width != texWidth
                || glassBackground.texture?.height != texHeight {
                glassBackground.texture = RenderTexture(
                    size: SizeInt(width: texWidth, height: texHeight),
                    scaleFactor: mainTexture.scaleFactor,
                    format: .bgra8,
                    debugLabel: "GlassBackground"
                )
            }

            guard let bgTexture = glassBackground.texture else {
                return
            }

            let commandBuffer = renderContext.commandQueue.makeCommandBuffer()
            commandBuffer.label = "Glass Background Capture"

            let blitEncoder = commandBuffer.beginBlitPass(BlitPassDescriptor(label: "Glass Background Blit"))
            blitEncoder.copyTextureToTexture(
                source: mainTexture,
                sourceOrigin: Origin3D(),
                sourceSize: Size3D(width: texWidth, height: texHeight),
                sourceMipLevel: 0,
                sourceSlice: 0,
                destination: bgTexture,
                destinationOrigin: Origin3D(),
                destinationMipLevel: 0,
                destinationSlice: 0
            )
            blitEncoder.endBlitPass()
            commandBuffer.commit()
        }

        return []
    }
}
