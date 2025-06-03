//
//  RenderSurface.swift
//  AdaEngine
//
//  Created by v.prusakov on 9/10/21.
//

/// A protocol that defines a render surface.
/// Wrap platform specific view to render surface.
public protocol RenderSurface { }

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)

import MetalKit

extension MTKView: RenderSurface { }

#endif
