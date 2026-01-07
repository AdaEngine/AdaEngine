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
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
import MetalKit
import QuartzCore
#endif
#if os(Windows)
import WinSDK
#endif

final class WGPUContext: Sendable {
    let device: WebGPU.Device
    let adapter: WebGPU.Adapter
    let instance: WebGPU.Instance

    private let windows = Mutex<[WindowID: WGPURenderWindow]>([:])

    init(device: WebGPU.Device, adapter: WebGPU.Adapter, instance: WebGPU.Instance) {
        self.device = device
        self.adapter = adapter
        self.instance = instance
    }

    @MainActor
    func createWindow(_ windowId: WindowID, for surface: any RenderSurface, size: Math.SizeInt) throws {
        let existingWindow = self.windows.withLock { $0[windowId] }
        guard existingWindow == nil else {
            throw ContextError.creationWindowAlreadyExists
        }

        let surfaceDescriptor = surface.createWebGPUSurface()
        let wgpuSurface = instance.createSurface(descriptor: surfaceDescriptor)
        
        wgpuSurface.configure(
            config: SurfaceConfiguration(
                device: device,
                format: surface.prefferedPixelFormat.toWebGPU,
                usage: .renderAttachment,
                width: UInt32(size.width),
                height: UInt32(size.height),
                viewFormats: [surface.prefferedPixelFormat.toWebGPU],
                alphaMode: .auto,
                presentMode: PresentMode.fifo
            )
        )
        let renderWindow = WGPURenderWindow(
            windowId: windowId,
            surface: wgpuSurface,
            pixelFormat: surface.prefferedPixelFormat,
            size: size,
            scaleFactor: surface.scaleFactor
        )

        self.windows.withLock { @MainActor windows in
            windows[windowId] = renderWindow
        }
    }

    @MainActor
    func resizeWindow(_ windowId: WindowID, newSize: Math.SizeInt) throws {
        guard newSize.width > 0 && newSize.height > 0 else {
            return
        }
        
        try self.windows.withLock { windows in
            guard var window = windows[windowId] else {
                throw ContextError.windowNotFound
            }
            
            // Reconfigure the surface with the new size
            window.surface.configure(
                config: SurfaceConfiguration(
                    device: device,
                    format: window.pixelFormat.toWebGPU,
                    usage: .renderAttachment,
                    width: UInt32(newSize.width),
                    height: UInt32(newSize.height),
                    viewFormats: [window.pixelFormat.toWebGPU],
                    alphaMode: .auto,
                    presentMode: PresentMode.fifo
                )
            )
            
            window.size = newSize
            windows[windowId] = window
        }
    }

    func destroyWindow(_ windowId: WindowID) throws {
        try self.windows.withLock {
            guard $0[windowId] != nil else {
                throw ContextError.windowNotFound
            }
            $0.removeValue(forKey: windowId)
        }
    }

    func getRenderWindow(for windowId: WindowID) -> AdaRender.RenderWindow? {
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

    func getWGPURenderWindow(for windowId: WindowID) -> WGPURenderWindow? {
        self.windows.withLock { windows in
            return windows[windowId]
        }
    }

    func getRenderWindows() throws -> AdaRender.RenderWindows {
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

    @safe
    struct WGPURenderWindow {
        let windowId: WindowID
        let surface: WebGPU.Surface
        let pixelFormat: PixelFormat
        var size: Math.SizeInt
        let scaleFactor: Float
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

#if os(macOS)
        let view = (self as! MTKView)
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        view.framebufferOnly = false
        view.sampleCount = 1
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
