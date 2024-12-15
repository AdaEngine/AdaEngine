//
//  RenderBackend.swift
//  AdaEngine
//
//  Created by v.prusakov on 10/9/21.
//

import Math

public enum TriangleFillMode {
    case fill
    case lines
}

/// This protocol describe interface for GPU.
protocol RenderBackend: AnyObject {

    /// Returns current frame index. Min value 0, Max value is equal ``RenderEngine/Configuration/maxFramesInFlight`` value.
    var currentFrameIndex: Int { get }

    /// Returns global ``RenderingDevice``.
    var renderingDevice: RenderingDevice { get }

    /// Create a local renderign device, that can render only in texture.
    func createLocalRenderingDevice() -> RenderingDevice

    /// Register a new render window for render backend.
    /// Window in this case is entity that managed a drawables (aka swapchain).
    /// - Throws: Throw error if something went wrong.
    @MainActor func createWindow(_ windowId: UIWindow.ID, for surface: RenderSurface, size: SizeInt) throws

    /// Resize registred render window.
    /// - Throws: Throw error if window is not registred.
    @MainActor func resizeWindow(_ windowId: UIWindow.ID, newSize: SizeInt) throws

    /// Destroy render window from render backend.
    /// - Throws: Throw error if window is not registred.
    @MainActor func destroyWindow(_ windowId: UIWindow.ID) throws

    /// Begin rendering a frame for all windows.
    @MainActor func beginFrame() throws

    /// Release any data associated with the current frame.
    @MainActor func endFrame() throws
}
