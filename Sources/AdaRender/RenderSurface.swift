//
//  RenderSurface.swift
//  AdaEngine
//
//  Created by v.prusakov on 9/10/21.
//

/// A protocol that defines a render surface.
/// Wrap platform specific view to render surface.
@MainActor
public protocol RenderSurface {
    var scaleFactor: Float { get }
    var prefferedPixelFormat: PixelFormat { get }
}

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)

import MetalKit

extension MTKView: RenderSurface {
    public var scaleFactor: Float {
        Float(self.layer!.contentsScale)
    }

    public var prefferedPixelFormat: PixelFormat {
        self.colorPixelFormat.toPixelFormat()
    }
}

#endif

#if os(Windows)
import WinSDK

/// Windows-specific render surface implementation.
/// This wraps a Win32 window handle for use with the rendering system.
public final class WindowsSurface: RenderSurface {
    public let windowId: WindowID
    public let windowHwnd: UnsafeMutableRawPointer

    public var scaleFactor: Float { 1 }
    public var prefferedPixelFormat: PixelFormat { .bgra8 }

    public init(windowId: WindowID, windowHwnd: UnsafeMutableRawPointer) {
        self.windowId = windowId
        unsafe self.windowHwnd = unsafe windowHwnd
    }
}
#endif