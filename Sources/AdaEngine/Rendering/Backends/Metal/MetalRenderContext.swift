//
//  File.swift
//  
//
//  Created by v.prusakov on 5/16/22.
//

#if METAL
import Metal

extension MetalRenderBackend {
    
    final class Context {
        
        class RenderWindow {
            
            private(set) weak var view: MetalView?
            let commandQueue: MTLCommandQueue
            var viewport: MTLViewport
            
            var albedoTexture: MTLTexture!
            var commandBuffer: MTLCommandBuffer?
            
            internal init(view: MetalView? = nil, commandQueue: MTLCommandQueue, viewport: MTLViewport, commandBuffer: MTLCommandBuffer? = nil) {
                self.view = view
                self.commandQueue = commandQueue
                self.viewport = viewport
                self.commandBuffer = commandBuffer
            }
            
            func updateSize() {
                let size = self.view!.drawableSize
                if size.width <= 0 && size.height <= 0 {
                    return
                }
                
                let textureDesc = MTLTextureDescriptor.texture2DDescriptor(
                    pixelFormat: .bgra8Unorm_srgb,
                    width: Int(size.width),
                    height: Int(size.height),
                    mipmapped: false
                )
                
                textureDesc.usage = [.renderTarget, .shaderRead]
                let texture = self.view!.device?.makeTexture(descriptor: textureDesc)
                
                self.albedoTexture = texture
                
//                self.renderPassDescriptor.colorAttachments[0].texture = texture
//                self.renderPassDescriptor.colorAttachments[0].storeAction = .store
//                self.renderPassDescriptor.colorAttachments[0].loadAction = .clear
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
            
            let viewport = MTLViewport(
                originX: 0,
                originY: 0,
                width: Double(size.width),
                height: Double(size.height),
                znear: 0,
                zfar: 1
            )
            
            let window = RenderWindow(
                view: view,
                commandQueue: commandQueue,
                viewport: viewport
            )
            
            view.depthStencilPixelFormat = .depth32Float_stencil8
            view.colorPixelFormat = .bgra8Unorm_srgb
            view.device = self.physicalDevice
            view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
            view.framebufferOnly = false
            view.sampleCount = 1
            
            window.updateSize()
            
            self.windows[id] = window
        }
        
        func updateSizeForRenderWindow(_ windowId: Window.ID, size: Size) {
            guard let window = self.windows[windowId] else {
                assertionFailure("Not found window by id \(windowId)")
                return
            }
            
            window.viewport = MTLViewport(
                originX: 0,
                originY: 0,
                width: Double(size.width),
                height: Double(size.height),
                znear: 0,
                zfar: 1
            )
            
            window.updateSize()
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
