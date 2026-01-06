#if canImport(WebGPU)
import WebGPU
import AdaUtils

final class WGPUSwapchain: Swapchain, @unchecked Sendable {

    let renderWindow: WGPUContext.WGPURenderWindow

    init(renderWindow: WGPUContext.WGPURenderWindow) {
        self.renderWindow = renderWindow
    }

    var drawablePixelFormat: PixelFormat {
        renderWindow.pixelFormat
    }

    func getNextDrawable(_ renderDevice: RenderDevice) -> (any Drawable)? {
        return WGPUSwapchainDrawable(surface: renderWindow.surface)
    }
}

final class WGPUSwapchainDrawable: Drawable, @unchecked Sendable {
    let texture: any GPUTexture
    let surface: WebGPU.Surface

    init(surface: WebGPU.Surface) {
        self.surface = surface
        self.texture = WGPUGPUTexture(
            texture: surface.currentTexture.texture, 
            textureView: surface.currentTexture.texture.createView(
                descriptor: WebGPU.TextureViewDescriptor(
                    format: surface.currentTexture.texture.format,
                    dimension: surface.currentTexture.texture.dimension.toTextureViewDimension,
                    usage: [.renderAttachment, .textureBinding]
                )
            )
        )
    }

    func present() throws {
        let value = surface.present()
        if value != .success {
            throw DrawableError.failedToPresentDrawable
        }
    }
}

enum DrawableError: Error {
    case failedToPresentDrawable
}

extension WebGPU.TextureDimension {
    var toTextureViewDimension: TextureViewDimension {
        switch self {
        case .type1d: return .type1d
        case .type2d: return .type2d
        case .type3d: return .type3d
        case .typeUndefined: return .typeUndefined

}
    }
}
#endif