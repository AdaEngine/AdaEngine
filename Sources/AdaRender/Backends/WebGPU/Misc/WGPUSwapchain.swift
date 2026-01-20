#if canImport(WebGPU)
import WebGPU
import AdaUtils
import Logging
import Foundation

final class WGPUSwapchain: Swapchain, @unchecked Sendable {

    let renderWindow: WGPUContext.WGPURenderWindow
    var previousDrawable: (any Drawable)?
    var currentDrawable: (any Drawable)?

    init(renderWindow: WGPUContext.WGPURenderWindow) {
        self.renderWindow = renderWindow
    }

    var drawablePixelFormat: PixelFormat {
        renderWindow.pixelFormat
    }

    func getNextDrawable(_ renderDevice: RenderDevice) -> (any Drawable)? {
        do {
            let surfaceTexture: SurfaceTexture = try renderWindow.surface.getCurrentTexture() 
            guard surfaceTexture.status == .successOptimal || surfaceTexture.status == .successSuboptimal else {
                return nil
            }
            return WGPUSwapchainDrawable(
                surface: renderWindow.surface,
                surfaceTexture: surfaceTexture
            )
        } catch {
            Logger(label: "org.adaengine.webgpu").error("\(error.localizedDescription)")
            return nil
        }
    }
}

final class WGPUSwapchainDrawable: Drawable, @unchecked Sendable {
    let texture: any GPUTexture
    let surface: WebGPU.Surface
    let surfaceTexture: WebGPU.SurfaceTexture
    var isPresented: Bool = false

    init(surface: WebGPU.Surface, surfaceTexture: WebGPU.SurfaceTexture) {
        self.surface = surface
        self.surfaceTexture = surfaceTexture
        self.texture = WGPUGPUTexture(
            texture: surfaceTexture.texture, 
            textureView: surfaceTexture.texture.createView()
        )
    }

    func present() throws {
        assert(!isPresented, "Drawable is already presented")
        let value = surface.present()
        self.isPresented = true
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