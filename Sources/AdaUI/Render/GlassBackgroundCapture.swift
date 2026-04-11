//
//  GlassBackgroundCapture.swift
//  AdaEngine
//

import AdaECS
import AdaRender
import Math

/// Holds the captured background texture used by the glass effect.
///
/// Filled each frame inside ``UIRenderNode`` (blit from the camera main target into this
/// texture on the **same** command buffer as the UI pass) so GPU ordering is guaranteed.
/// Glass quads sample from this texture to produce blur and refraction.
public final class GlassBackgroundTexture: Resource, @unchecked Sendable {
    public var texture: RenderTexture?

    public init() {}
}
