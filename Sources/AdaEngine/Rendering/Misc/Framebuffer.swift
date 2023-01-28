//
//  Framebuffer.swift
//  
//
//  Created by v.prusakov on 1/22/23.
//

public struct FramebufferDescriptor {
    public var width: Int = 0
    public var height: Int = 0
    
    public var sampleCount = 0
}

public protocol Framebuffer: AnyObject {
    
    var size: Size { get }
    
    var descriptor: FramebufferDescriptor { get }
    var renderPass: RenderPass { get }
}

#if METAL

import Metal

class MetalFramebuffer: Framebuffer {
    
    private let mtlViewport: MTLViewport
    
    let size: Size
    
    let descriptor: FramebufferDescriptor
    let renderPass: RenderPass
    
    init(viewport: MTLViewport, descriptor: FramebufferDescriptor, renderPass: RenderPass) {
        self.mtlViewport = viewport
        self.descriptor = descriptor
        self.size = Size(width: Float(descriptor.width), height: Float(descriptor.height))
        self.renderPass = renderPass
    }
}

#endif
