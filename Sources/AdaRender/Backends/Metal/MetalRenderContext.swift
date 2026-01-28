//
//  MetalRenderContext.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/16/22.
//

#if METAL
import Metal
import QuartzCore
import Math
import AdaUtils
import MetalKit

extension MetalRenderBackend {

    final class Context: @unchecked Sendable {
        private(set) var windows: [WindowID: MetalRenderWindow] = [:]
        let physicalDevice: MTLDevice
        
        init() {
            self.physicalDevice = Self.prefferedDevice()
            let needsShowDebugHUD = ProcessInfo.processInfo.environment["METAL_HUD_DEBUG"] != nil
            UserDefaults.standard.set(needsShowDebugHUD, forKey: "MetalForceHudEnabled")
        }

        func getRenderWindow(for window: WindowID) -> MetalRenderWindow? {
            windows[window]
        }

        // MARK: - Methods
        @MainActor
        func createRenderWindow(with id: WindowID, view: MTKView, size: SizeInt) throws {
            if windows[id] != nil {
                throw ContextError.creationWindowAlreadyExists
            }

            let window = MetalRenderWindow(
                view: view,
                size: size,
                scaleFactor: view.scaleFactor
            )
            view.colorPixelFormat = .bgra8Unorm
            view.device = self.physicalDevice
            view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
            view.framebufferOnly = false
            view.sampleCount = 1

            let layer = view.layer as? CAMetalLayer
            layer?.maximumDrawableCount = unsafe RenderEngine.configurations.maxFramesInFlight
            layer?.allowsNextDrawableTimeout = true

            self.windows[id] = window
        }
        
        func updateSizeForRenderWindow(_ windowId: WindowID, size: SizeInt) {
            windows[windowId]?.size = size
        }
        
        func destroyWindow(by id: WindowID) {
            guard self.windows[id] != nil else {
                assertionFailure("Not found window by id \(id)")
                return
            }
            self.windows[id] = nil
        }
        
        // MARK: - Private
        
        private static func prefferedDevice() -> MTLDevice {
            #if !os(macOS)
            // For ios/tvOS/ipadOS we have only one device
            return MTLCreateSystemDefaultDevice()!
            #endif
            // TODO: (Vlad) Make picking preffered device, currently we picked descrete GPU
            return MTLCreateSystemDefaultDevice()!
        }
        
        enum ContextError: LocalizedError {
            case creationWindowAlreadyExists
            case commandQueueCreationFailed
            
            var errorDescription: String? {
                switch self {
                case .creationWindowAlreadyExists:
                    return "MetalRenderWindow Creation Failed: Window by given id already exists."
                case .commandQueueCreationFailed:
                    return "MetalRenderWindow Creation Failed: MTLDevice cannot create MTLCommandQueue."
                }
            }
        }
    }
    
    struct MetalRenderWindow: Sendable {
        let view: MTKView
        var size: SizeInt
        var scaleFactor: Float

        init(view: MTKView, size: SizeInt, scaleFactor: Float) {
            self.view = view
            self.size = size
            self.scaleFactor = scaleFactor
        }
    }
}

#endif
