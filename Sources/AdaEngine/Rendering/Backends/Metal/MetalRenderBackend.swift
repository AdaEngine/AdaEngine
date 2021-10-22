//
//  File.swift
//  
//
//  Created by v.prusakov on 10/20/21.
//

#if canImport(Metal)
import Metal
import Math

class MetalRenderBackend: RenderBackend {
    
    let context: MetalContext
    
    init(appName: String) {
        self.context = MetalContext()
    }
    
    func createWindow(for view: RenderView, size: Vector2i) throws {
        let mtlView = (view as! MetalView)
        self.context.createWindow(for: mtlView)
    }
    
    func resizeWindow(newSize: Vector2i) throws {
        
    }
    
    func beginFrame() throws {
        
    }
    
    func endFrame() throws {
        
    }
}

class MetalContext {
    
    var device: MTLDevice!
    
    init() {
        
    }
    
    func createWindow(for view: MetalView) {
        self.device = view.preferredDevice
        
    }
}

#endif
