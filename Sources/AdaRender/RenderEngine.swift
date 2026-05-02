//
//  RenderEngine.swift
//  AdaEngine
//
//  Created by v.prusakov on 10/25/21.
//

import AdaUtils
import OrderedCollections
import Math

/// Global information about buffer index.
public enum GlobalBufferIndex {
    public static let viewUniform: Int = 2
}

/// Render Engine is object that manage a GPU.
public final class RenderEngine: RenderBackend, Sendable {

    
    public struct Configuration {
        /// The maximum number of frames in flight.
        public var maxFramesInFlight: Int = 3

        /// The preferred backend to use for rendering.
        public var preferredBackend: RenderBackendType?

        public init() {}
    }
    
    /// Setup configuration for render engine
    nonisolated(unsafe) public static var configurations: Configuration = Configuration()
    
    /// Return instance of render engine for specific backend.
    public fileprivate(set) nonisolated(unsafe) static var shared: RenderEngine!
    
    private let renderBackend: RenderBackend
    
    init(renderBackend: RenderBackend) {
        self.renderBackend = renderBackend
    }
    
    // MARK: - RenderBackend
    
    public var type: RenderBackendType {
        self.renderBackend.type
    }

    /// Returns global ``RenderDevice``.
    public var renderDevice: RenderDevice {
        return self.renderBackend.renderDevice
    }

    public func createLocalRenderDevice() -> RenderDevice {
        return self.renderBackend.createLocalRenderDevice()
    }

    public func createWindow(_ windowId: WindowID, for surface: RenderSurface, size: SizeInt) throws {
        try self.renderBackend.createWindow(windowId, for: surface, size: size)
    }
    
    public func resizeWindow(_ windowId: WindowID, newSize: SizeInt) throws {
        try self.renderBackend.resizeWindow(windowId, newSize: newSize)
    }

    @MainActor
    public func resizeWindow(_ windowId: WindowID, newSize: SizeInt, scaleFactor: Float) throws {
        #if WEBGPU_ENABLED
        if let webGPUBackend = self.renderBackend as? WebGPURenderBackend {
            try webGPUBackend.resizeWindow(windowId, newSize: newSize, scaleFactor: scaleFactor)
            return
        }
        #endif

        try self.renderBackend.resizeWindow(windowId, newSize: newSize)
    }
    
    public func destroyWindow(_ windowId: WindowID) throws {
        try self.renderBackend.destroyWindow(windowId)
    }

    func getRenderWindow(for windowId: WindowID) -> RenderWindow? {
        self.renderBackend.getRenderWindow(for: windowId)
    }

    public func getRenderWindows() throws -> RenderWindows {
        try self.renderBackend.getRenderWindows()
    }
}

public extension RenderDevice {
    func createUniformBuffer<T>(_ uniformType: T.Type, count: Int = 1, binding: Int) -> UniformBuffer {
        self.createUniformBuffer(length: MemoryLayout<T>.stride * count, binding: binding)
    }
}

extension RenderEngine {
    package static func setupRenderEngine() throws {
        // Guard: only the first caller creates the engine; subsequent callers (e.g. SceneView
        // subworld) reuse the existing instance so the main window registration is preserved.
        guard unsafe RenderEngine.shared == nil else { return }
        let preferredBackend = unsafe RenderEngine.configurations.preferredBackend ?? Self.defaultBackendType()
        let renderBackend: RenderBackend
        switch preferredBackend {
        case .webgpu:
        #if WEBGPU_ENABLED
            renderBackend = try WebGPURenderBackend.createBackend()
        #else
            fallthrough
        #endif
        case .metal:
        #if METAL
            renderBackend = MetalRenderBackend()
        #else
            fallthrough
        #endif
        case .headless:
            renderBackend = HeadlessRenderBackend()
        }
        let engine = RenderEngine(renderBackend: renderBackend)
        unsafe RenderEngine.shared = engine
    }

    private static func defaultBackendType() -> RenderBackendType {
        #if WEBGPU_ENABLED
        return .webgpu
        #elseif METAL
        return .metal
        #else
        return .headless
        #endif
    }
}
