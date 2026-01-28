//
//  WGPUContext.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 04.01.2026.
//

#if canImport(WebGPU)
import WebGPU
import CWebGPU
import Math
import AdaUtils
import Synchronization
import Foundation
#if canImport(MetalKit)
import MetalKit
import QuartzCore
#endif
#if os(Windows)
import WinSDK
#endif

public final class WGPUContext: Sendable {
    public let device: WebGPU.Device
    public let adapter: WebGPU.Adapter
    let instance: WebGPU.Instance

    private let windows = Mutex<[WindowID: WGPURenderWindow]>([:])

    init(device: WebGPU.Device, adapter: WebGPU.Adapter, instance: WebGPU.Instance) {
        self.device = device
        self.adapter = adapter
        self.instance = instance
    }

    @MainActor
    public func createWindow(_ windowId: WindowID, for surface: any RenderSurface, size: Math.SizeInt) throws {
        let existingWindow = self.windows.withLock { $0[windowId] }
        guard existingWindow == nil else {
            throw ContextError.creationWindowAlreadyExists
        }

        let surfaceDescriptor = surface.createWebGPUSurface()
        let wgpuSurface = instance.createSurface(descriptor: surfaceDescriptor)
        configureSurface(surface: wgpuSurface, size: size, pixelFormat: surface.prefferedPixelFormat)
        self.windows.withLock { @MainActor windows in
            windows[windowId] = WGPURenderWindow(
                windowId: windowId,
                surface: wgpuSurface,
                pixelFormat: surface.prefferedPixelFormat,
                size: size,
                scaleFactor: surface.scaleFactor
            )
        }
    }

    @MainActor
    public func resizeWindow(_ windowId: WindowID, newSize: Math.SizeInt) throws {
        guard newSize.width > 0 && newSize.height > 0 else {
            return
        }
        
        try self.windows.withLock { windows in
            guard var window = windows[windowId] else {
                throw ContextError.windowNotFound
            }
            configureSurface(
                surface: window.surface, 
                size: newSize, 
                pixelFormat: window.pixelFormat
            )
            window.size = newSize
            windows[windowId] = window
        }
    }

    public func destroyWindow(_ windowId: WindowID) throws {
        try self.windows.withLock {
            guard $0[windowId] != nil else {
                throw ContextError.windowNotFound
            }
            $0.removeValue(forKey: windowId)
        }
    }

    public func getRenderWindow(for windowId: WindowID) -> AdaRender.RenderWindow? {
        self.windows.withLock { windows in
            guard let window = windows[windowId] else {
                return nil
            }
            return AdaRender.RenderWindow(
                windowId: window.windowId,
                height: window.size.height,
                width: window.size.width,
                scaleFactor: window.scaleFactor
            )
        }
    }

    @inline(__always)
    public func getWGPURenderWindow(for windowId: WindowID) -> WGPURenderWindow? {
        self.windows.withLock { windows in
            return windows[windowId]
        }
    }

    public func getRenderWindows() throws -> AdaRender.RenderWindows {
        let windows = self.windows.withLock { $0 }
        var renderWindows = SparseSet<WindowID, AdaRender.RenderWindow>()
        for (windowId, window) in windows {
            renderWindows[windowId] = AdaRender.RenderWindow(
                windowId: window.windowId,
                height: window.size.height,
                width: window.size.width,
                scaleFactor: window.scaleFactor
            )
        }

        return AdaRender.RenderWindows(windows: renderWindows)
    }

    private func configureSurface(
        surface: WebGPU.Surface, 
        size: Math.SizeInt, 
        pixelFormat: PixelFormat
    ) {
        surface.configure(
            config: SurfaceConfiguration(
                device: device,
                format: pixelFormat.toWebGPU,
                usage: .renderAttachment,
                width: UInt32(size.width),
                height: UInt32(size.height),
                viewFormats: [],
                alphaMode: .auto,
                presentMode: PresentMode.fifo
            )
        )
    }

    @safe
    public struct WGPURenderWindow {
        public let windowId: WindowID
        public let surface: WebGPU.Surface
        public let pixelFormat: PixelFormat
        public var size: Math.SizeInt
        public let scaleFactor: Float
    }

    enum ContextError: LocalizedError {
        case creationWindowAlreadyExists
        case windowNotFound
        case invalidSurface
        case platformNotSupported

        var errorDescription: String? {
            switch self {
            case .creationWindowAlreadyExists:
                return "WebGPURenderWindow Creation Failed: Window by given id already exists."
            case .windowNotFound:
                return "WebGPURenderWindow: Window not found."
            case .invalidSurface:
                return "WebGPURenderWindow: Invalid surface provided."
            case .platformNotSupported:
                return "WebGPURenderWindow: Platform not supported."
            }
        }
    }
}

extension RenderSurface {
    @MainActor
    func createWebGPUSurface() -> WebGPU.SurfaceDescriptor {
        var surfaceDescriptor = SurfaceDescriptor()

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        let view = (self as! MTKView)
        surfaceDescriptor.nextInChain = unsafe SurfaceSourceMetalLayer(
            layer: Unmanaged.passUnretained(view.layer!).toOpaque()
        )
#elseif os(Linux)
        surfaceDescriptor.nextInChain = unsafe SurfaceSourceXlibWindow(
            display: UnsafeMutableRawPointer(glfwGetX11Display()),
            window: UInt64(glfwGetX11Window(handle))
        )
#elseif os(Windows)
        let surface = (self as! WindowsSurface)
        surfaceDescriptor.nextInChain = unsafe SurfaceSourceWindowsHwnd(
            hinstance: GetModuleHandleW(nil),
            hwnd: surface.windowHwnd
        )
#endif

        return surfaceDescriptor
    }
}


#endif
