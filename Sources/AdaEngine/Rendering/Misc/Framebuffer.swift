//
//  Framebuffer.swift
//  
//
//  Created by v.prusakov on 1/22/23.
//

public struct FramebufferDescriptor {
    public var sampleCount = 0
    public var renderPass: RenderPassDescriptor
}

public struct FramebufferAttachmentUsage: OptionSet {
    public var rawValue: UInt16
    
    public init(rawValue: UInt16) {
        self.rawValue = rawValue
    }
}

public extension FramebufferAttachmentUsage {
    static let colorAttachment = FramebufferAttachmentUsage(rawValue: 1 << 0)
    
    static let depthStencilAttachment = FramebufferAttachmentUsage(rawValue: 1 << 1)
    
    static let sampling = FramebufferAttachmentUsage(rawValue: 1 << 2)
    
    static let empty: FramebufferAttachmentUsage = []
}

public struct FramebufferAttachment {
    public let texture: Texture2D?
    public let pixelFormat: PixelFormat
    public let usage: FramebufferAttachmentUsage
}

public protocol Framebuffer: AnyObject {
    var attachments: [FramebufferAttachment] { get }
    
    var descriptor: FramebufferDescriptor { get }
    var renderPass: RenderPass { get }
}

#if METAL

import Metal

class MetalFramebuffer: Framebuffer {
    
    private(set) var attachments: [FramebufferAttachment]
    private(set) var descriptor: FramebufferDescriptor
    private(set) var renderPass: RenderPass
    
    init(
        descriptor: FramebufferDescriptor,
        renderPass: RenderPass,
        attachments: [FramebufferAttachment]
    ) {
        self.descriptor = descriptor
        self.renderPass = renderPass
        self.attachments = attachments
    }
}

#endif
