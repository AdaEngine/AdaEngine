//
//  RenderPipeline.swift
//  AdaEngine
//
//  Created by v.prusakov on 1/8/23.
//

// TODO: (Vlad) Add documentations

public protocol RenderPipeline: AnyObject {
    var descriptor: RenderPipelineDescriptor { get }
}

public struct VertexBufferDescriptor {
    public var attributes = VertexDescriptorAttributesArray()
    public var layouts = VertexDescriptorLayoutsArray()
    
    mutating func reset() {
        self.attributes = VertexDescriptorAttributesArray()
        self.layouts = VertexDescriptorLayoutsArray()
    }
}

public struct StencilOperationDescriptor {
    public var fail: StencilOperation = .zero
    public var pass: StencilOperation = .zero
    public var depthFail: StencilOperation = .zero
    public var compare: CompareOperation = .always
    public var writeMask: UInt32 = 0
}

public struct DepthStencilDescriptor {
    public var isDepthTestEnabled: Bool = true
    public var isDepthWriteEnabled: Bool = true
    public var depthCompareOperator: CompareOperation = .greaterOrEqual
    public var isDepthRangeEnabled: Bool = false
    public var depthRangeMin: Float = 0
    public var depthRangeMax: Float = 0
    public var isEnableStencil = false
    public var stencilOperationDescriptor: StencilOperationDescriptor?
}

public struct ColorAttachmentDescriptor {
    public var format: PixelFormat
    
    public var isBlendingEnabled: Bool = false
    
    public var sourceRGBBlendFactor: BlendFactor = .sourceAlpha
    public var sourceAlphaBlendFactor: BlendFactor = .sourceAlpha
    public var rgbBlendOperation: BlendOperation = .add
    public var alphaBlendOperation: BlendOperation = .add
    public var destinationAlphaBlendFactor: BlendFactor = .oneMinusSourceAlpha
    public var destinationRGBBlendFactor: BlendFactor = .oneMinusSourceAlpha
}

public protocol ShaderFunction {
    
}

public struct RenderPipelineDescriptor {
    public var shaderModule: ShaderModule?
    public var debugName: String = ""
    public var backfaceCulling: Bool = true
    public var primitive: IndexPrimitive = .triangle
    public var vertexDescriptor: VertexBufferDescriptor = VertexBufferDescriptor()
    
    public var depthStencilDescriptor: DepthStencilDescriptor?
    public var depthPixelFormat: PixelFormat = .depth_32f_stencil8
    
    public var colorAttachments: [ColorAttachmentDescriptor] = []
    
    public init() { }
}
