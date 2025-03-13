//
//  OpenGLBackend.swift
//  AdaEngine
//
//  Created by vladislav.prusakov on 13.03.2025.
//

#if WASM
import WebGL
#endif
#if DARWIN
import OpenGL.GL3
#else
import OpenGL
#endif
import Math

final class OpenGLBackend: RenderBackend {

    var currentFrameIndex: Int = 0
    
    let renderDevice: any RenderDevice
    let context: Context

    init(appName: String) {
        self.context = Context()
        self.renderDevice = OpenGLRenderDevice(context: context)
    }

    func createLocalRenderDevice() -> any RenderDevice {
        OpenGLRenderDevice()
    }
    
    func createWindow(_ windowId: UIWindow.ID, for surface: any RenderSurface, size: Math.SizeInt) throws {
        try self.context.createWindow(windowId, for: surface, size: size)
    }
    
    func resizeWindow(_ windowId: UIWindow.ID, newSize: Math.SizeInt) throws {
        try self.context.resizeWindow(windowId, newSize: newSize)
    }
    
    func destroyWindow(_ windowId: UIWindow.ID) throws {
        try self.context.destroyWindow(windowId)
    }
    
    func beginFrame() throws {
        
    }
    
    func endFrame() throws {
        
    }
}
