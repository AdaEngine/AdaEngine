//
//  RenderEngine.swift
//  AdaEngine
//
//  Created by v.prusakov on 10/25/21.
//

import OrderedCollections
import Math

public enum GlobalBufferIndex {
    public static let viewUniform: Int = 1
}

/// Render Engine is object that manage a GPU.
public final class RenderEngine: RenderBackend {
    
    public struct Configuration {
        public var maxFramesInFlight: Int = 3
        public init() {}
    }
    
    /// Setup configuration for render engine
    nonisolated(unsafe) public static var configurations: Configuration = Configuration()
    
    /// Return instance of render engine for specific backend.
    nonisolated(unsafe) public static let shared: RenderEngine = {
        let renderBackend: RenderBackend

        let appName = "AdaEngine"

        // #if METAL
        // renderBackend = MetalRenderBackend(appName: appName)
        // #elseif VULKAN
        // renderBackend = VulkanRenderBackend(appName: appName)
        // #else
        // renderBackend = OpenGLBackend(appName: appName)
        // #endif

       renderBackend = OpenGLBackend(appName: appName)

        return RenderEngine(renderBackend: renderBackend)
    }()
    
    private let renderBackend: RenderBackend
    
    private init(renderBackend: RenderBackend) {
        self.renderBackend = renderBackend
    }
    
    // MARK: - RenderBackend
    
    public var currentFrameIndex: Int {
        return self.renderBackend.currentFrameIndex
    }

    /// Returns global ``RenderDevice``.
    public var renderDevice: RenderDevice {
        return self.renderBackend.renderDevice
    }

    public func createLocalRenderDevice() -> RenderDevice {
        return self.renderBackend.createLocalRenderDevice()
    }

    public func createWindow(_ windowId: UIWindow.ID, for surface: RenderSurface, size: SizeInt) throws {
        try self.renderBackend.createWindow(windowId, for: surface, size: size)
    }
    
    public func resizeWindow(_ windowId: UIWindow.ID, newSize: SizeInt) throws {
        try self.renderBackend.resizeWindow(windowId, newSize: newSize)
    }
    
    public func destroyWindow(_ windowId: UIWindow.ID) throws {
        try self.renderBackend.destroyWindow(windowId)
    }
    
    func beginFrame() throws {
        preconditionMainThreadOnly()
        try self.renderBackend.beginFrame()
    }
    
    func endFrame() throws {
        preconditionMainThreadOnly()
        try self.renderBackend.endFrame()
    }
}

public extension RenderDevice {
    func createUniformBuffer<T>(_ uniformType: T.Type, count: Int = 1, binding: Int) -> UniformBuffer {
        self.createUniformBuffer(length: MemoryLayout<T>.stride * count, binding: binding)
    }
}
