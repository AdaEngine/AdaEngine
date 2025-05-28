//
//  RenderSurface.swift
//  AdaEngine
//
//  Created by v.prusakov on 9/10/21.
//

public protocol RenderSurface { }

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)

import MetalKit

extension MTKView: RenderSurface { }

#endif
