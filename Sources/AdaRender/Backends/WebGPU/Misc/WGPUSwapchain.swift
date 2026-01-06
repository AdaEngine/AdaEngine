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

    var texture: any GPUTexture { 
        WGPUGPUTexture(
            texture: surface.currentTexture.texture, 
            textureView: surface.currentTexture.texture.createView()
        )
    }

    let surface: WebGPU.Surface

    init(surface: WebGPU.Surface) {
        self.surface = surface
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
#endif