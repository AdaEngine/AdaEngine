//
//  RenderPassDescriptor.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 26.11.2025.
//

import AdaUtils
import Math

public struct RenderPassDescriptor: Sendable {

    public var label: String?

    public var colorAttachments: [RenderPassColorAttachmentDescriptor]

    public var depthStencilAttachment: DepthStencilAttachmentDescriptor?

    public init(
        label: String? = nil,
        colorAttachments: [RenderPassColorAttachmentDescriptor],
        depthStencilAttachment: DepthStencilAttachmentDescriptor? = nil
    ) {
        self.colorAttachments = colorAttachments
        self.depthStencilAttachment = depthStencilAttachment
    }
}

public struct RenderPassColorAttachmentDescriptor: Sendable {

    public var texture: Texture

    public var resolveTexture: Texture?

    public var operation: OperationDescriptor?

    public var clearColor: Color?

    public init(
        texture: Texture,
        resolveTexture: Texture? = nil,
        operation: OperationDescriptor? = nil,
        clearColor: Color? = nil
    ) {
        self.texture = texture
        self.resolveTexture = resolveTexture
        self.operation = operation
        self.clearColor = clearColor
    }
}
