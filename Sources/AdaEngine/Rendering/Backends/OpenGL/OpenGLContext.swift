//
//  OpenGLContext.swift
//  AdaEngine
//
//  Created by vladislav.prusakov on 13.03.2025.
//

#if WASM
import WebGL
#endif
#if DARWIN

#if canImport(AppKit)
import AppKit
#endif

import OpenGL.GL3
#else
import OpenGL
#endif
import Math

extension OpenGLBackend {

    enum RenderError: Error {
        case windowAlreadyExists
        case windowNotFound
    }

    final class Context {
        private(set) var windows: [UIWindow.ID: RenderWindow] = [:]

        @MainActor
        func createWindow(
            _ windowId: UIWindow.ID,
            for surface: any RenderSurface,
            size: Math.SizeInt
        ) throws {
            guard self.windows[windowId] == nil else {
                throw RenderError.windowAlreadyExists
            }

            let context = try surface.createGLContext()
            context.makeCurrent()
            self.windows[windowId] = RenderWindow(openGLContext: context)
        }

        @MainActor
        func resizeWindow(_ windowId: UIWindow.ID, newSize: Math.SizeInt) throws {
            guard let window = self.windows[windowId] else {
                throw RenderError.windowNotFound
            }
        }

        @MainActor
        func destroyWindow(_ windowId: UIWindow.ID) throws {
            guard self.windows[windowId] != nil else {
                throw RenderError.windowNotFound
            }

            self.windows[windowId] = nil
        }
    }
}

extension OpenGLBackend.Context {
    struct RenderWindow {
        let openGLContext: OpenGLContext
    }
}

protocol OpenGLContext: AnyObject {
    func makeCurrent()
    
    func flushBuffer()
}

private extension RenderSurface {
    @MainActor
    func createGLContext() throws -> OpenGLContext {
#if DARWIN
    #if canImport(AppKit)
        var attributes: [NSOpenGLPixelFormatAttribute] = [
            NSOpenGLPixelFormatAttribute(NSOpenGLPFAAccelerated),
            NSOpenGLPixelFormatAttribute(NSOpenGLPFADoubleBuffer),
            NSOpenGLPixelFormatAttribute(NSOpenGLPFAColorSize), 24,
            NSOpenGLPixelFormatAttribute(NSOpenGLPFAAlphaSize), 8,
            NSOpenGLPixelFormatAttribute(NSOpenGLPFADepthSize), 16,
            NSOpenGLPixelFormatAttribute(0)
        ]
        guard let format = NSOpenGLPixelFormat(attributes: &attributes) else {
            fatalError("Failed to create OpenGL pixel format")
        }

        let context = NSOpenGLContext(format: format, share: nil)!
        context.view = self as! MetalView

        return context
    #else
        fatalErrorMethodNotImplemented()
    #endif
#elseif WASM
        fatalErrorMethodNotImplemented()
#elseif os(Windows)
        fatalErrorMethodNotImplemented()
#else
        fatalErrorMethodNotImplemented()
#endif
    }
}

#if canImport(AppKit)
extension NSOpenGLContext: OpenGLContext {
    func makeCurrent() {
        OpenGLBackend.currentContext = self
        self.makeCurrentContext()
    }
}
#endif
