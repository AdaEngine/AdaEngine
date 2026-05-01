#if canImport(WebGPU)
@unsafe @preconcurrency import WebGPU
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
        var surfaceTexture = WGPUSurfaceTexture()
        renderWindow.surface.getCurrentTexture(surfaceTexture: &surfaceTexture)
        let textureStatus = surfaceTexture.status
        guard textureStatus == .successOptimal || textureStatus == .successSuboptimal else {
            return nil
        }
        return WGPUSwapchainDrawable(
            surface: renderWindow.surface,
            surfaceTexture: WebGPU.GPUSurfaceTexture(wgpuStruct: surfaceTexture)
        )
    }
}

final class WGPUSwapchainDrawable: Drawable, @unchecked Sendable {
    let texture: any GPUTexture
    let surface: WebGPU.GPUSurface
    let surfaceTexture: WebGPU.GPUSurfaceTexture
    var isPresented: Bool = false

    init(surface: WebGPU.GPUSurface, surfaceTexture: WebGPU.GPUSurfaceTexture) {
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

extension WebGPU.GPUTextureDimension {
    var toTextureViewDimension: WebGPU.GPUTextureViewDimension {
        switch self {
        case ._1D: return ._1D
        case ._2D: return ._2D
        case ._3D: return ._3D
        case .undefined: return .undefined
        default: return .undefined
        }
    }
}
#endif
