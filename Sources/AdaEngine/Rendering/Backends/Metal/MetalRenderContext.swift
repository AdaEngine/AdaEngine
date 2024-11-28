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

extension MetalRenderBackend {

    final class Context {
        private(set) var windows: [UIWindow.ID: RenderWindow] = [:]
        let physicalDevice: MTLDevice
        
        init() {
            self.physicalDevice = Self.prefferedDevice()
            let needsShowDebugHUD = ProcessInfo.processInfo.environment["METAL_HUD_DEBUG"] != nil
            UserDefaults.standard.set(needsShowDebugHUD, forKey: "MetalForceHudEnabled")
        }
        
        // MARK: - Methods
        @MainActor func createRenderWindow(with id: UIWindow.ID, view: MetalView, size: SizeInt) throws {
            if self.windows[id] != nil {
                throw ContextError.creationWindowAlreadyExists
            }
            
            let window = RenderWindow(view: view)
            
            // TODO: (Vlad) We should setup it in different place?
            view.colorPixelFormat = .bgra8Unorm
            view.device = self.physicalDevice
            view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
            view.framebufferOnly = false
            view.sampleCount = 1
            
            self.windows[id] = window
        }
        
        func updateSizeForRenderWindow(_ windowId: UIWindow.ID, size: SizeInt) {
//            guard let window = self.windows[windowId] else {
//                assertionFailure("Not found window by id \(windowId)")
//                return
//            }
            
//            window.view?.drawableSize = size.toCGSize
        }
        
        func destroyWindow(by id: UIWindow.ID) {
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
                    return "RenderWindow Creation Failed: Window by given id already exists."
                case .commandQueueCreationFailed:
                    return "RenderWindow Creation Failed: MTLDevice cannot create MTLCommandQueue."
                }
            }
        }
    }
    
    final class RenderWindow {
        private(set) weak var view: MetalView?
        var drawable: CAMetalDrawable?
        var commandBuffer: MTLCommandBuffer?
        
        internal init(
            view: MetalView? = nil,
            commandBuffer: MTLCommandBuffer? = nil
        ) {
            self.view = view
            self.commandBuffer = commandBuffer
        }
        
        func getRenderPass() -> MTLRenderPassDescriptor? {
            guard let drawable else {
                return nil
            }
            
            let mtlRenderPass = MTLRenderPassDescriptor()
            mtlRenderPass.colorAttachments[0].texture = drawable.texture
            return mtlRenderPass
        }
    }
}

#endif
