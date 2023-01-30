//
//  File.swift
//  
//
//  Created by v.prusakov on 5/16/22.
//

#if METAL
import Metal
import QuartzCore

extension MetalRenderBackend {
    
    final class Context {
        
        class RenderWindow {
            
            private(set) weak var view: MetalView?
            let commandQueue: MTLCommandQueue
            var drawable: CAMetalDrawable?
            var commandBuffer: MTLCommandBuffer?
            
            internal init(
                view: MetalView? = nil,
                commandQueue: MTLCommandQueue,
                commandBuffer: MTLCommandBuffer? = nil
            ) {
                self.view = view
                self.commandQueue = commandQueue
                self.commandBuffer = commandBuffer
            }
            
            func getRenderPass() -> MTLRenderPassDescriptor {
                let mtlRenderPass = MTLRenderPassDescriptor()
                mtlRenderPass.colorAttachments[0].texture = self.drawable?.texture
                mtlRenderPass.colorAttachments[0].loadAction = .clear
                mtlRenderPass.colorAttachments[0].storeAction = .store
                return mtlRenderPass
            }
        }
        
        private(set) var windows: [Window.ID: RenderWindow] = [:]
        
        let physicalDevice: MTLDevice
        
        init() {
            self.physicalDevice = Self.prefferedDevice()
        }
        
        // MARK: - Methods
        
        func createRenderWindow(with id: Window.ID, view: MetalView, size: Size) throws {
            if self.windows[id] != nil {
                throw ContextError.creationWindowAlreadyExists
            }
            
            guard let commandQueue = physicalDevice.makeCommandQueue() else {
                throw ContextError.commandQueueCreationFailed
            }
            
            let window = RenderWindow(
                view: view,
                commandQueue: commandQueue
            )
            
            // TODO: (Vlad) We should setup it in different place?
            view.colorPixelFormat = .bgra8Unorm
            view.device = self.physicalDevice
            view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
            view.framebufferOnly = false
            view.sampleCount = 1
            
            self.windows[id] = window
        }
        
        func updateSizeForRenderWindow(_ windowId: Window.ID, size: Size) {
            guard let window = self.windows[windowId] else {
                assertionFailure("Not found window by id \(windowId)")
                return
            }
            
//            window.view?.drawableSize = size.toCGSize
        }
        
        func destroyWindow(by id: Window.ID) {
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
            
//            let allDevices = MTLCopyAllDevices()
            
            // TODO: (Vlad) Make picking preffered device, currently we picked descrete GPU
            var prefferedDevice: MTLDevice?
            
            return prefferedDevice ?? MTLCreateSystemDefaultDevice()!
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
}

#endif
