//
//  RenderEngine.swift
//  
//
//  Created by v.prusakov on 10/25/21.
//

import OrderedCollections

public class RenderEngine {
    
    public static let shared: RenderEngine = {
        let renderBackend: RenderBackend
        
        #if METAL
        renderBackend = MetalRenderBackend(appName: "Ada Engine")
        #else
        fatalError()
        #endif
        
        return RenderEngine(renderBackend: renderBackend)
    }()
    
    let renderBackend: RenderBackend
    
    private init(renderBackend: RenderBackend) {
        self.renderBackend = renderBackend
    }
    
    // MARK: Methods
    
    public func setClearColor(_ color: Color, forWindow windowId: Window.ID) {
        self.renderBackend.setClearColor(color, forWindow: windowId)
    }
    
    public func beginFrame() throws {
        try self.renderBackend.beginFrame()
    }
    
    public func endFrame() throws {
        try self.renderBackend.endFrame()
    }
    
    public func createWindow(_ windowId: Window.ID, for view: RenderView, size: Size) throws {
        try self.renderBackend.createWindow(windowId, for: view, size: size)
    }
    
    public func updateWindowSize(_ window: Window.ID, newSize: Size) throws {
        guard newSize.width > 0 && newSize.height > 0 else {
            return
        }
        
        try self.renderBackend.resizeWindow(window, newSize: newSize)
    }
    
    // MARK: - Buffers
    
    func makeBuffer(length: Int, options: ResourceOptions) -> RID {
        return self.renderBackend.makeBuffer(length: length, options: options)
    }
    
    func makeBuffer(bytes: UnsafeRawPointer, length: Int, options: ResourceOptions) -> RID {
        return self.renderBackend.makeBuffer(bytes: bytes, length: length, options: options)
    }
    
    func getBuffer(for rid: RID) -> RenderBuffer {
        return self.renderBackend.getBuffer(for: rid)
    }
}
