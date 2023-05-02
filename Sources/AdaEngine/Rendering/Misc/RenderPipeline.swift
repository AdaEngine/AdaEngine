//
//  RenderPipeline.swift
//  AdaEngine
//
//  Created by v.prusakov on 1/8/23.
//

// TODO: (Vlad) Add documentations

/// An object that contains graphics functions and configuration state to use in a render command.
public protocol RenderPipeline: AnyObject {
    
    /// /// Contains information about render pipeline descriptor.
    var descriptor: RenderPipelineDescriptor { get }
}

/// An object that defines the front-facing or back-facing stencil operations of a depth and stencil state object.
public struct StencilOperationDescriptor {
    
    /// The operation that is performed to update the values in the stencil attachment when the stencil test fails.
    public var fail: StencilOperation
    
    /// The operation that is performed to update the values in the stencil attachment when both the stencil test and the depth test pass.
    public var pass: StencilOperation
    
    /// The operation that is performed to update the values in the stencil attachment when the stencil test passes, but the depth test fails.
    public var depthFail: StencilOperation
    
    /// The comparison that is performed between the masked reference value and a masked value in the stencil attachment.
    public var compare: CompareOperation
    
    /// A bitmask that determines to which bits that stencil operations can write.
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

/// An object that configures new depth and stencil operation.
public struct DepthStencilDescriptor {
    
    public var isDepthTestEnabled: Bool
    
    /// A Boolean value that indicates whether depth values can be written to the depth attachment.
    public var isDepthWriteEnabled: Bool
    
    /// The comparison that is performed between a fragment’s depth value and the depth value in the attachment, which determines whether to discard the fragment.
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

/// An object specifies the rendering configuration state to use during a rendering pass,
/// including rasterization (such as multisampling), visibility, blending, tessellation, and graphics function state.
///
/// To specify the vertex or fragment function in the rendering pipeline descriptor, set the vertex or fragment property.
public struct RenderPipelineDescriptor {
    
    /// The vertex shader the pipeline run to process vertices.
    public var vertex: Shader?
    
    /// The fragment shader the pipeline run to process fragments.
    public var fragment: Shader?
    
    /// A string that identifies the render pipeline descriptor.
    public var debugName: String = ""
    
    public var backfaceCulling: Bool = true
    public var primitive: IndexPrimitive = .triangle
    
    /// The organization of vertex data in an attribute’s argument table.
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
