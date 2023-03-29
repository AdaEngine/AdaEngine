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

public struct StencilOperationDescriptor {
    public var fail: StencilOperation
    public var pass: StencilOperation
    public var depthFail: StencilOperation
    public var compare: CompareOperation
    public var writeMask: UInt32
    
    public init(
        fail: StencilOperation = .zero,
        pass: StencilOperation = .zero,
        depthFail: StencilOperation = .zero,
        compare: CompareOperation = .always,
        writeMask: UInt32 = 0
    ) {
        self.fail = fail
        self.pass = pass
        self.depthFail = depthFail
        self.compare = compare
        self.writeMask = writeMask
    }
}

public struct DepthStencilDescriptor {
    public var isDepthTestEnabled: Bool
    public var isDepthWriteEnabled: Bool
    public var depthCompareOperator: CompareOperation
    public var isDepthRangeEnabled: Bool
    public var depthRangeMin: Float
    public var depthRangeMax: Float
    public var isEnableStencil: Bool
    public var stencilOperationDescriptor: StencilOperationDescriptor?
    
    public init(
        isDepthTestEnabled: Bool = true,
        isDepthWriteEnabled: Bool = true,
        depthCompareOperator: CompareOperation = .greaterOrEqual,
        isDepthRangeEnabled: Bool = false,
        depthRangeMin: Float = 0,
        depthRangeMax: Float = 0,
        isEnableStencil: Bool = false,
        stencilOperationDescriptor: StencilOperationDescriptor? = nil
    ) {
        self.isDepthTestEnabled = isDepthTestEnabled
        self.isDepthWriteEnabled = isDepthWriteEnabled
        self.depthCompareOperator = depthCompareOperator
        self.isDepthRangeEnabled = isDepthRangeEnabled
        self.depthRangeMin = depthRangeMin
        self.depthRangeMax = depthRangeMax
        self.isEnableStencil = isEnableStencil
        self.stencilOperationDescriptor = stencilOperationDescriptor
    }
}

public struct ColorAttachmentDescriptor {
    public var format: PixelFormat
    
    public var isBlendingEnabled: Bool = false
    
    public var sourceRGBBlendFactor: BlendFactor
    public var sourceAlphaBlendFactor: BlendFactor
    public var rgbBlendOperation: BlendOperation
    public var alphaBlendOperation: BlendOperation
    public var destinationAlphaBlendFactor: BlendFactor
    public var destinationRGBBlendFactor: BlendFactor
    
    public init(
        format: PixelFormat,
        isBlendingEnabled: Bool = false,
        sourceRGBBlendFactor: BlendFactor = .sourceAlpha,
        sourceAlphaBlendFactor: BlendFactor = .sourceAlpha,
        rgbBlendOperation: BlendOperation = .add,
        alphaBlendOperation: BlendOperation = .add,
        destinationAlphaBlendFactor: BlendFactor = .oneMinusSourceAlpha,
        destinationRGBBlendFactor: BlendFactor = .oneMinusSourceAlpha
    ) {
        self.format = format
        self.isBlendingEnabled = isBlendingEnabled
        self.sourceRGBBlendFactor = sourceRGBBlendFactor
        self.sourceAlphaBlendFactor = sourceAlphaBlendFactor
        self.rgbBlendOperation = rgbBlendOperation
        self.alphaBlendOperation = alphaBlendOperation
        self.destinationAlphaBlendFactor = destinationAlphaBlendFactor
        self.destinationRGBBlendFactor = destinationRGBBlendFactor
    }
}

public protocol ShaderFunction {
    
}

public struct RenderPipelineDescriptor {
    public var vertex: Shader?
    public var fragment: Shader?
    public var debugName: String = ""
    public var backfaceCulling: Bool = true
    public var primitive: IndexPrimitive = .triangle
    public var vertexDescriptor: VertexDescriptor = VertexDescriptor()
    
    public var depthStencilDescriptor: DepthStencilDescriptor?
    public var depthPixelFormat: PixelFormat = .depth_32f_stencil8
    
    public var colorAttachments: [ColorAttachmentDescriptor] = []
    
    public init(
        vertex: Shader? = nil,
        fragment: Shader? = nil,
        debugName: String = "",
        backfaceCulling: Bool = true,
        primitive: IndexPrimitive = .triangle,
        vertexDescriptor: VertexDescriptor = VertexDescriptor(),
        depthStencilDescriptor: DepthStencilDescriptor? = nil,
        depthPixelFormat: PixelFormat = .depth_32f_stencil8,
        colorAttachments: [ColorAttachmentDescriptor] = []
    ) {
        self.vertex = vertex
        self.fragment = fragment
        self.debugName = debugName
        self.backfaceCulling = backfaceCulling
        self.primitive = primitive
        self.vertexDescriptor = vertexDescriptor
        self.depthStencilDescriptor = depthStencilDescriptor
        self.depthPixelFormat = depthPixelFormat
        self.colorAttachments = colorAttachments
    }
}
