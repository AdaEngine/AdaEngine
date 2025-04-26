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
import Foundation

#if DARWIN
private let GL_DEBUG_OUTPUT = GLenum(0x92E0)
private let GL_DEBUG_OUTPUT_SYNCHRONOUS = GLenum(0x8242)
#endif

final class OpenGLBackend: RenderBackend {

    let type: RenderBackendType = .opengl
    var currentFrameIndex: Int = 0

    nonisolated(unsafe) static var currentContext: OpenGLContext?

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
        for (_, window) in self.context.windows {
            window.openGLContext.flushBuffer()
        }
        
        glFinish()
        currentFrameIndex = (currentFrameIndex + 1) % RenderEngine.configurations.maxFramesInFlight
    }
}
