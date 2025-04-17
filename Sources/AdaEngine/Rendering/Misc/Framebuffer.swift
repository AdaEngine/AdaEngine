//
//  Framebuffer.swift
//  AdaEngine
//
//  Created by v.prusakov on 1/22/23.
//

import Math

/// Describes the configuration of a framebuffer.
public struct FramebufferDescriptor {
    /// The scale factor for the framebuffer.
    public var scale: Float
    
    /// The width of the framebuffer.
    public var width: Int
    
    /// The height of the framebuffer.
    public var height: Int
    
    /// The sample count for the framebuffer.
    public var sampleCount: Int
    
    /// The clear depth for the framebuffer.
    public var clearDepth: Double
    
    /// The load action for the depth attachment.
    public var depthLoadAction: AttachmentLoadAction
    
    /// The attachments for the framebuffer.
    public var attachments: [FramebufferAttachmentDescriptor]

    public init(
        scale: Float = 1.0,
        width: Int = 0,
        height: Int = 0,
        sampleCount: Int = 0,
        clearDepth: Double = 0, 
        depthLoadAction: AttachmentLoadAction = .clear,
        attachments: [FramebufferAttachmentDescriptor] = []
    ) {
        self.scale = scale
        self.width = width
        self.height = height
        self.sampleCount = sampleCount
        self.clearDepth = clearDepth
        self.depthLoadAction = depthLoadAction
        self.attachments = attachments
    }
}

/// Describes the usage of a framebuffer attachment.
public struct FramebufferAttachmentUsage: OptionSet, Sendable {
    public var rawValue: UInt16
    
    public init(rawValue: UInt16) {
        self.rawValue = rawValue
    }
}

public extension FramebufferAttachmentUsage {
    /// The color attachment usage.
    static let colorAttachment = FramebufferAttachmentUsage(rawValue: 1 << 0)
    
    /// The depth stencil attachment usage.
    static let depthStencilAttachment = FramebufferAttachmentUsage(rawValue: 1 << 1)
    
    /// The sampling attachment usage.
    static let sampling = FramebufferAttachmentUsage(rawValue: 1 << 2)
    
    /// The empty attachment usage.
    static let empty: FramebufferAttachmentUsage = []
}

/// Describes the configuration of a framebuffer attachment.
public struct FramebufferAttachmentDescriptor {
    /// The format of the attachment.
    public var format: PixelFormat
    
    /// The texture of the attachment.
    public var texture: RenderTexture?
    
    /// The clear color of the attachment.
    public var clearColor: Color
    
    /// The load action for the attachment.
    public var loadAction: AttachmentLoadAction
    
    /// The store action for the attachment.
    public var storeAction: AttachmentStoreAction
    
    /// The slice of the attachment.
    public var slice: Int = 0

    public init(
        format: PixelFormat,
        texture: RenderTexture? = nil,
        clearColor: Color = Color(0, 0, 0, 1),
        loadAction: AttachmentLoadAction = .clear,
        storeAction: AttachmentStoreAction = .store
    ) {
        self.format = format
        self.texture = texture
        self.clearColor = clearColor
        self.loadAction = loadAction
        self.storeAction = storeAction
    }
}

/// Represents a framebuffer attachment.
public struct FramebufferAttachment: Sendable {
    /// The texture of the attachment.
    public let texture: RenderTexture?
    
    /// The clear color of the attachment.
    public internal(set) var clearColor: Color
    
    /// The usage of the attachment.
    public internal(set) var usage: FramebufferAttachmentUsage
    
    /// The slice of the attachment.
    public internal(set) var slice: Int

    public init(
        texture: RenderTexture? = nil,
        clearColor: Color = Color(0, 0, 0, 1),
        usage: FramebufferAttachmentUsage = [],
        slice: Int = 0
    ) {
        self.texture = texture
        self.clearColor = clearColor
        self.usage = usage
        self.slice = slice
    }
}

/// Represents a framebuffer.
public protocol Framebuffer: AnyObject {
    /// The attachments of the framebuffer.
    var attachments: [FramebufferAttachment] { get }
    
    /// The descriptor of the framebuffer.
    var descriptor: FramebufferDescriptor { get }
    
    /// Resizes the framebuffer to a new size.
    func resize(to newSize: SizeInt)
    
    /// Invalidates the framebuffer.
    func invalidate()
}
