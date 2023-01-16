//
//  RenderPipeline.swift
//  AdaEngine
//
//  Created by v.prusakov on 1/8/23.
//

public protocol RenderPipeline: AnyObject {
    var descriptor: RenderPipelineDescriptor { get }
}

public enum CompareOperation: UInt {

    case never
    case always

    case equal
    case notEqual
    case less
    case lessOrEqual
    case greater
    case greaterOrEqual
}

public struct VertexBufferDescriptor {
    public var attributes = VertexDescriptorAttributesArray()
    public var layouts = VertexDescriptorLayoutsArray()
    
    mutating func reset() {
        self.attributes = VertexDescriptorAttributesArray()
        self.layouts = VertexDescriptorLayoutsArray()
    }
}

public enum StencilOperation: UInt {
    case zero
    case keep
    case replace
    case incrementAndClamp
    case decrementAndClamp
    case invert
    case incrementAndWrap
    case decrementAndWrap
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

public struct RenderPipelineDescriptor {
    public var shader: Shader
    public var debugName: String = ""
    public var backfaceCulling: Bool = true
    public var primitive: IndexPrimitive = .triangle
    public var vertexDescriptor: VertexBufferDescriptor = VertexBufferDescriptor()
    
    public var depthStencilDescriptor: DepthStencilDescriptor?
    public var depthPixelFormat: PixelFormat = .depth_32f_stencil8
    
    public var colorAttachments: [ColorAttachmentDescriptor] = []
    
    public init(shader: Shader) {
        self.shader = shader
    }
}

#if METAL
import Metal

class MetalRenderPipeline: RenderPipeline {
    
    let descriptor: RenderPipelineDescriptor
    let renderPipeline: MTLRenderPipelineState
    let depthStencilState: MTLDepthStencilState?
    
    init(descriptor: RenderPipelineDescriptor, renderPipeline: MTLRenderPipelineState, depthState: MTLDepthStencilState?) {
        self.descriptor = descriptor
        self.renderPipeline = renderPipeline
        self.depthStencilState = depthState
    }
    
}
#endif

public enum AttachmentLoadAction {
    case clear
    case load
    case dontCare
}

public enum PixelFormat {
    case none
    
    case bgra8
    case bgra8_srgb
    
    case rgba8
    case rgba_16f
    case rgba_32f
    
    case depth_32f_stencil8
    case depth_32f
    case depth24_stencil8
    
    var isDepthFormat: Bool {
        self == .depth_32f_stencil8 || self == .depth_32f || self == .depth24_stencil8
    }
}

public enum BlendFactor: UInt {
    
    case zero
    
    case one
    
    case sourceColor
    
    case oneMinusSourceColor
    
    case sourceAlpha
    
    case oneMinusSourceAlpha
    
    case destinationColor
    
    case oneMinusDestinationColor
    
    case destinationAlpha
    
    case oneMinusDestinationAlpha
    
    case sourceAlphaSaturated
    
    case blendColor
    
    case oneMinusBlendColor
    
    case blendAlpha
    
    case oneMinusBlendAlpha
}

public enum BlendOperation: UInt {
    
    case add
    
    case subtract
    
    case reverseSubtract
    
    case min
    
    case max
}

public struct ColorAttachmentDescriptor {
    public var format: PixelFormat
    
    public var isBlendingEnabled: Bool = true
    
    public var sourceRGBBlendFactor: BlendFactor = .sourceAlpha
    public var sourceAlphaBlendFactor: BlendFactor = .sourceAlpha
    public var rgbBlendOperation: BlendOperation = .add
    public var alphaBlendOperation: BlendOperation = .add
    public var destinationAlphaBlendFactor: BlendFactor = .oneMinusSourceAlpha
    public var destinationRGBBlendFactor: BlendFactor = .oneMinusSourceAlpha
}

public struct RenderAttachmentDescriptor {
    public var format: PixelFormat
    public var clearColor: Color = Color(0, 0, 0, 1)
    public var loadAction: AttachmentLoadAction = .clear
    public var slice: Int = 0
}

public struct RenderPassDescriptor {
    public var clearDepth: Double = 0
    
    public var depthLoadAction: AttachmentLoadAction = .clear
    
    public var attachments: [RenderAttachmentDescriptor] = []
}

public protocol RenderPass: AnyObject {
    var descriptor: RenderPassDescriptor { get }
}

#if METAL
class MetalRenderPass: RenderPass {
    
    let descriptor: RenderPassDescriptor
    let renderPass: MTLRenderPassDescriptor
    
    init(descriptor: RenderPassDescriptor, renderPass: MTLRenderPassDescriptor) {
        self.descriptor = descriptor
        self.renderPass = renderPass
    }
}
#endif
