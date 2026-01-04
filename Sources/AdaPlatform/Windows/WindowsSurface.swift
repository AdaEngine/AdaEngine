//
//  WindowsSurface.swift
//  AdaEngine
//
//  Created by v.prusakov on 9/10/21.
//

#if os(Windows)
import AdaRender
import WinSDK

/// Windows-specific render surface implementation.
/// This wraps a Win32 window handle for use with the rendering system.
public final class WindowsSurface: RenderSurface {
    public let windowId: WindowID
    public let windowHwnd: UnsafeMutableRawPointer

    public init(windowId: WindowID, windowHwnd: UnsafeMutableRawPointer) {
        self.windowId = windowId
        self.windowHwnd = windowHwnd
    }
}

#endif

