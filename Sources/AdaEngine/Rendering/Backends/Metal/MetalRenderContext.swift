//
//  File.swift
//  
//
//  Created by v.prusakov on 5/16/22.
//

#if canImport(Metal)
import Metal

extension MetalRenderBackend {
    
    final class Context {
        
        weak var view: MetalView!
        
        var device: MTLDevice!
        var commandQueue: MTLCommandQueue!
        var viewport: MTLViewport = MTLViewport()
        var pipelineState: MTLRenderPipelineState!
        
        // MARK: - Methods
        
        func createWindow(for view: MetalView) throws {
            
            self.view = view
            
            self.viewport = MTLViewport(originX: 0, originY: 0, width: Double(view.drawableSize.width), height: Double(view.drawableSize.height), znear: 0, zfar: 1)
            
            self.device = self.prefferedDevice(for: view)
            view.device = self.device
            
            self.commandQueue = self.device.makeCommandQueue()
        }
        
        func prefferedDevice(for view: MetalView) -> MTLDevice {
            return view.preferredDevice ?? MTLCreateSystemDefaultDevice()!
        }
        
        func windowUpdateSize(_ size: Size) {
            self.viewport = MTLViewport(originX: 0, originY: 0, width: Double(size.width), height: Double(size.height), znear: 0, zfar: 1)
        }
        
    }
}

#endif
