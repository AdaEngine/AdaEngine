//
//  WGPURenderPipeline.swift
//  AdaEngine
//
//  Created by v.prusakov on 1/18/23.
//

#if canImport(WebGPU)
import AdaUtils
import WebGPU

final class WGPURenderPipeline: RenderPipeline {
    
    let descriptor: RenderPipelineDescriptor
    let renderPipeline: WebGPU.RenderPipeline
    
    init(
        descriptor: RenderPipelineDescriptor,
        device: WebGPU.Device
    ) {
        let vertex = (descriptor.vertex.compiledShader as? WGPUShader).unwrap(message: "Vertex shader is not a WGPUShader")

        // Build vertex buffer layouts - group attributes by buffer index
        var bufferAttributes: [Int: [VertexAttribute]] = [:]
        var bufferStrides: [Int: Int] = [:]
        
        for (attrIndex, attribute) in descriptor.vertexDescriptor.attributes.buffer.enumerated() {
            let bufferIndex = attribute.bufferIndex
            let wgpuAttribute = VertexAttribute(
                format: attribute.format.toWebGPU,
                offset: UInt64(attribute.offset),
                shaderLocation: UInt32(attrIndex)
            )
            bufferAttributes[bufferIndex, default: []].append(wgpuAttribute)
        }
        
        // Get strides for each buffer (using buffer directly to avoid mutating getter)
        for bufferIndex in bufferAttributes.keys {
            if bufferIndex < descriptor.vertexDescriptor.layouts.buffer.count {
                bufferStrides[bufferIndex] = descriptor.vertexDescriptor.layouts.buffer[bufferIndex].stride
            }
        }
        
        // Fallback: if stride not found, use 0 or calculate from attributes
        let vertexBuffers = bufferAttributes.keys.sorted().map { bufferIndex in
            let stride = bufferStrides[bufferIndex] ?? 0
            return VertexBufferLayout(
                stepMode: VertexStepMode.vertex,
                arrayStride: UInt64(stride),
                attributes: bufferAttributes[bufferIndex] ?? [],
                nextInChain: nil
            )
        }

        // Build fragment state
        let fragmentState: WebGPU.FragmentState? = descriptor.fragment.map { shader in
            let wgpuShader = (shader.compiledShader as? WGPUShader).unwrap(message: "Fragment shader is not a WGPUShader")
            
            let targets = descriptor.colorAttachments.map { attachment in
                ColorTargetState(
                    format: attachment.format.toWebGPU,
                    blend: attachment.isBlendingEnabled ? BlendState(
                        color: BlendComponent(
                            operation: attachment.rgbBlendOperation.toWebGPU,
                            srcFactor: attachment.sourceRGBBlendFactor.toWebGPU,
                            dstFactor: attachment.destinationRGBBlendFactor.toWebGPU
                        ),
                        alpha: BlendComponent(
                            operation: attachment.alphaBlendOperation.toWebGPU,
                            srcFactor: attachment.sourceAlphaBlendFactor.toWebGPU,
                            dstFactor: attachment.destinationAlphaBlendFactor.toWebGPU
                        )
                    ) : nil,
                    writeMask: ColorWriteMask.all
                )
            }
            
            return WebGPU.FragmentState(
                module: wgpuShader.shader,
                entryPoint: shader.entryPoint,
                constants: [],
                targets: targets
            )
        }

        // Build depth stencil state
        let depthStencilState: DepthStencilState? = descriptor.depthStencilDescriptor.map { depthDesc in
            let stencilOp = depthDesc.stencilOperationDescriptor
            return DepthStencilState(
                format: descriptor.depthPixelFormat.toWebGPU,
                depthWriteEnabled: depthDesc.isDepthWriteEnabled,
                depthCompare: depthDesc.depthCompareOperator.toWebGPU,
                stencilFront: StencilFaceState(
                    compare: stencilOp?.compare.toWebGPU ?? .always,
                    failOp: stencilOp?.fail.toWebGPU ?? .keep,
                    depthFailOp: stencilOp?.depthFail.toWebGPU ?? .keep,
                    passOp: stencilOp?.pass.toWebGPU ?? .keep
                ),
                stencilBack: StencilFaceState(
                    compare: stencilOp?.compare.toWebGPU ?? .always,
                    failOp: stencilOp?.fail.toWebGPU ?? .keep,
                    depthFailOp: stencilOp?.depthFail.toWebGPU ?? .keep,
                    passOp: stencilOp?.pass.toWebGPU ?? .keep
                ),
                stencilReadMask: 0xFFFFFFFF,
                stencilWriteMask: 0xFFFFFFFF,
                depthBias: 0,
                depthBiasSlopeScale: 0,
                depthBiasClamp: 0
            )
        }

        self.descriptor = descriptor
        let topology = descriptor.primitive.toWebGPU
        let stripIndexFormat: IndexFormat = (topology == .triangleStrip || topology == .lineStrip) ? .uint32 : .undefined
        
        self.renderPipeline = device.createRenderPipeline(
            descriptor: WebGPU.RenderPipelineDescriptor(
                label: descriptor.debugName,
                layout: nil,
                vertex: VertexState(
                    module: vertex.shader,
                    entryPoint: descriptor.vertex.entryPoint,
                    constants: [],
                    buffers: vertexBuffers
                ),
                primitive: PrimitiveState(
                    topology: topology,
                    stripIndexFormat: stripIndexFormat,
                    frontFace: FrontFace.ccw,
                    cullMode: descriptor.backfaceCulling ? .back : .none,
                    unclippedDepth: false
                ),
                depthStencil: depthStencilState,
                multisample: MultisampleState(
                    count: 1,
                    mask: ~0,
                    alphaToCoverageEnabled: false
                ),
                fragment: fragmentState,
                nextInChain: nil
            )
        )
    }
}

extension WGPURenderPipeline {
    enum InitError: Error {
        case noVertexShader
    }
}

extension IndexPrimitive {
    var toWebGPU: PrimitiveTopology {
        switch self {
        case .triangle:         .triangleList
        case .triangleStrip:    .triangleStrip
        case .line:             .lineList
        case .lineStrip:        .lineStrip
        case .points:           .pointList
        }
    }
}

extension VertexFormat {
    var toWebGPU: WebGPU.VertexFormat {
        switch self {
        case .invalid:
            fatalError("Invalid vertex format cannot be converted to WebGPU")
        case .float:
            return .float32
        case .vector2:
            return .float32x2
        case .vector3:
            return .float32x3
        case .vector4:
            return .float32x4
        case .uint:
            return .uint32
        case .int:
            return .sint32
        case .char:
            return .uint8
        case .short:
            return .uint16
        }
    }
}

extension BlendFactor {
    var toWebGPU: WebGPU.BlendFactor {
        switch self {
        case .zero:
            return .zero
        case .one:
            return .one
        case .sourceColor:
            return .src
        case .oneMinusSourceColor:
            return .oneMinusSrc
        case .sourceAlpha:
            return .srcAlpha
        case .oneMinusSourceAlpha:
            return .oneMinusSrcAlpha
        case .destinationColor:
            return .dst
        case .oneMinusDestinationColor:
            return .oneMinusDst
        case .destinationAlpha:
            return .dstAlpha
        case .oneMinusDestinationAlpha:
            return .oneMinusDstAlpha
        case .sourceAlphaSaturated:
            return .srcAlphaSaturated
        case .blendColor:
            return .constant
        case .oneMinusBlendColor:
            return .oneMinusConstant
        case .blendAlpha:
            return .constant
        case .oneMinusBlendAlpha:
            return .oneMinusConstant
        }
    }
}

extension BlendOperation {
    var toWebGPU: WebGPU.BlendOperation {
        switch self {
        case .add:
            return .add
        case .subtract:
            return .subtract
        case .reverseSubtract:
            return .reverseSubtract
        case .min:
            return .min
        case .max:
            return .max
        }
    }
}

extension CompareOperation {
    var toWebGPU: WebGPU.CompareFunction {
        switch self {
        case .never:
            return .never
        case .less:
            return .less
        case .equal:
            return .equal
        case .lessOrEqual:
            return .lessEqual
        case .greater:
            return .greater
        case .notEqual:
            return .notEqual
        case .greaterOrEqual:
            return .greaterEqual
        case .always:
            return .always
        }
    }
}

extension StencilOperation {
    var toWebGPU: WebGPU.StencilOperation {
        switch self {
        case .keep:
            return .keep
        case .zero:
            return .zero
        case .replace:
            return .replace
        case .incrementAndClamp:
            return .incrementClamp
        case .decrementAndClamp:
            return .decrementClamp
        case .invert:
            return .invert
        case .incrementAndWrap:
            return .incrementWrap
        case .decrementAndWrap:
            return .decrementWrap
        }
    }
}
#endif
