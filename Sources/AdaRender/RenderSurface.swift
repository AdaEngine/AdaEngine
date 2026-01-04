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
