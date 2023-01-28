//
//  RenderPass.swift
//  
//
//  Created by v.prusakov on 1/18/23.
//

// TODO: (Vlad) Add documentations

public struct RenderAttachmentDescriptor {
    public var format: PixelFormat
    public var texture: RenderTexture?
    public var clearColor: Color = Color(0, 0, 0, 1)
    public var loadAction: AttachmentLoadAction = .clear
    public var storeAction: AttachmentStoreAction = .store
    public var slice: Int = 0
}

public struct RenderPassDescriptor {
    public var clearDepth: Double = 0
    
    public var depthLoadAction: AttachmentLoadAction = .clear
    
    public var attachments: [RenderAttachmentDescriptor] = []
    
    public var width: Int = 0
    public var height: Int = 0
}

public protocol RenderPass: AnyObject {
    var descriptor: RenderPassDescriptor { get }
}
