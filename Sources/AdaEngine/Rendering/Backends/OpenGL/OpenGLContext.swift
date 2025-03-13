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
        private var windows: [UIWindow.ID: RenderWindow] = [:]

        func createWindow(
            _ windowId: UIWindow.ID,
            for surface: any RenderSurface,
            size: Math.SizeInt
        ) throws {
            guard self.windows[windowId] == nil else {
                throw RenderError.windowAlreadyExists
            }

            self.windows[windowId] = RenderWindow()
        }

        func resizeWindow(_ windowId: UIWindow.ID, newSize: Math.SizeInt) throws {
            guard let window  = self.windows[windowId] else {
                throw RenderError.windowNotFound
            }
        }

        func destroyWindow(_ windowId: UIWindow.ID) throws {
            guard let window  = self.windows[windowId] else {
                throw RenderError.windowNotFound
            }

            self.windows[windowId] = nil
        }
    }
}

private extension OpenGLBackend.Context {
    final class RenderWindow {
        init() {
            
        }
    }
}

protocol OpenGLContext: AnyObject {

}

private extension RenderSurface {
    @MainActor
    func createGLContext() -> OpenGLContext {
#if DARWIN
    #if canImport(AppKit)
        let context = NSOpenGLContext()
        context.view = self as! MetalView
        return context as! OpenGLContext
    #else
        fatalErrorMethodNotImplemented()
    #endif
#elseif WASM
        fatalErrorMethodNotImplemented()
#else
        fatalErrorMethodNotImplemented()
#endif
    }
}
