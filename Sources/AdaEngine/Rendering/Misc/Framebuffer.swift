//
//  Framebuffer.swift
//  AdaEngine
//
//  Created by v.prusakov on 1/22/23.
//

// TODO: (Vlad) Add documentation

public struct FramebufferDescriptor {
    public var scale: Float = 1.0
    
    public var width: Int = 0
    public var height: Int = 0
    
    public var sampleCount = 0
    public var clearDepth: Double = 0
    public var depthLoadAction: AttachmentLoadAction = .clear
    public var attachments: [FramebufferAttachmentDescriptor] = []
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

public struct FramebufferAttachmentDescriptor {
    public var format: PixelFormat
    public var texture: RenderTexture?
    public var clearColor: Color = Color(0, 0, 0, 1)
    public var loadAction: AttachmentLoadAction = .clear
    public var storeAction: AttachmentStoreAction = .store
    public var slice: Int = 0
}

public struct FramebufferAttachment {
    public let texture: RenderTexture?
    public internal(set) var clearColor: Color = Color(0, 0, 0, 1)
    public internal(set) var usage: FramebufferAttachmentUsage = []
    public internal(set) var slice: Int = 0
}

public protocol Framebuffer: AnyObject {
    var attachments: [FramebufferAttachment] { get }
    var descriptor: FramebufferDescriptor { get }
    
    func resize(to newSize: Size)
    func invalidate()
}
