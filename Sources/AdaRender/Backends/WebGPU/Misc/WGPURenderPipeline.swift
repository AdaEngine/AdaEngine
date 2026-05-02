//
//  WGPURenderPipeline.swift
//  AdaEngine
//
//  Created by v.prusakov on 1/18/23.
//

#if canImport(WebGPU)
import AdaUtils
@unsafe @preconcurrency import WebGPU

final class WGPURenderPipeline: RenderPipeline, @unchecked Sendable {
    let descriptor: RenderPipelineDescriptor
    let renderPipeline: WebGPU.GPURenderPipeline

    init(
        descriptor: RenderPipelineDescriptor,
        device: WebGPU.GPUDevice
    ) {
        let vertex = (descriptor.vertex.compiledShader as? WGPUShader).unwrap(message: "Vertex shader is not a WGPUShader")
        let vertexBuffers = Self.makeVertexBuffers(from: descriptor)
        let fragmentState = Self.makeFragmentState(from: descriptor)
        let depthStencilState = Self.makeDepthStencilState(from: descriptor)

        self.descriptor = descriptor
        let topology = descriptor.primitive.toWebGPU
        let stripIndexFormat: WebGPU.GPUIndexFormat = (topology == .triangleStrip || topology == .lineStrip) ? .uint32 : .undefined

        self.renderPipeline = device.createRenderPipeline(
            descriptor: WebGPU.GPURenderPipelineDescriptor(
                label: descriptor.debugName,
                layout: nil,
                vertex: WebGPU.GPUVertexState(
                    module: vertex.shader,
                    entryPoint: vertex.entryPoint,
                    constants: [],
                    buffers: vertexBuffers
                ),
                primitive: WebGPU.GPUPrimitiveState(
                    topology: topology,
                    stripIndexFormat: stripIndexFormat,
                    frontFace: .CCW,
                    cullMode: descriptor.backfaceCulling ? .back : .none,
                    unclippedDepth: false
                ),
                depthStencil: depthStencilState,
                multisample: WebGPU.GPUMultisampleState(
                    count: 1,
                    mask: ~0,
                    alphaToCoverageEnabled: false
                ),
                fragment: fragmentState,
                nextInChain: nil
            )
        )
    }

    private static func makeVertexBuffers(from descriptor: RenderPipelineDescriptor) -> [WebGPU.GPUVertexBufferLayout] {
        var bufferAttributes: [Int: [WebGPU.GPUVertexAttribute]] = [:]
        var bufferStrides: [Int: Int] = [:]

        for (attrIndex, attribute) in descriptor.vertexDescriptor.attributes.buffer.enumerated() {
            let bufferIndex = attribute.bufferIndex
            let wgpuAttribute = WebGPU.GPUVertexAttribute(
                format: attribute.format.toWebGPU,
                offset: UInt64(attribute.offset),
                shaderLocation: UInt32(attrIndex)
            )
            bufferAttributes[bufferIndex, default: []].append(wgpuAttribute)
        }

        for bufferIndex in bufferAttributes.keys where bufferIndex < descriptor.vertexDescriptor.layouts.buffer.count {
            bufferStrides[bufferIndex] = descriptor.vertexDescriptor.layouts.buffer[bufferIndex].stride
        }

        return bufferAttributes.keys.sorted().map { bufferIndex in
            let stride = bufferStrides[bufferIndex] ?? 0
            return WebGPU.GPUVertexBufferLayout(
                stepMode: WebGPU.GPUVertexStepMode.vertex,
                arrayStride: UInt64(stride),
                attributes: bufferAttributes[bufferIndex] ?? [],
                nextInChain: nil
            )
        }
    }

    private static func makeFragmentState(from descriptor: RenderPipelineDescriptor) -> WebGPU.GPUFragmentState? {
        descriptor.fragment.map { shader in
            let wgpuShader = (shader.compiledShader as? WGPUShader).unwrap(message: "Fragment shader is not a WGPUShader")
            return WebGPU.GPUFragmentState(
                module: wgpuShader.shader,
                entryPoint: wgpuShader.entryPoint,
                constants: [],
                targets: descriptor.colorAttachments.map(makeColorTargetState)
            )
        }
    }

    private static func makeColorTargetState(from attachment: RenderPipelineColorAttachmentDescriptor) -> WebGPU.GPUColorTargetState {
        WebGPU.GPUColorTargetState(
            format: attachment.format.toWebGPU,
            blend: attachment.isBlendingEnabled ? WebGPU.GPUBlendState(
                color: WebGPU.GPUBlendComponent(
                    operation: attachment.rgbBlendOperation.toWebGPU,
                    srcFactor: attachment.sourceRGBBlendFactor.toWebGPU,
                    dstFactor: attachment.destinationRGBBlendFactor.toWebGPU
                ),
                alpha: WebGPU.GPUBlendComponent(
                    operation: attachment.alphaBlendOperation.toWebGPU,
                    srcFactor: attachment.sourceAlphaBlendFactor.toWebGPU,
                    dstFactor: attachment.destinationAlphaBlendFactor.toWebGPU
                )
            ) : nil,
            writeMask: WebGPU.GPUColorWriteMask.all
        )
    }

    private static func makeDepthStencilState(from descriptor: RenderPipelineDescriptor) -> WebGPU.GPUDepthStencilState? {
        descriptor.depthStencilDescriptor.map { depthDesc in
            let stencilOp = depthDesc.stencilOperationDescriptor
            return WebGPU.GPUDepthStencilState(
                format: descriptor.depthPixelFormat.toWebGPU,
                depthWriteEnabled: depthDesc.isDepthWriteEnabled ? .true : .false,
                depthCompare: depthDesc.depthCompareOperator.toWebGPU,
                stencilFront: Self.makeStencilFaceState(from: stencilOp),
                stencilBack: Self.makeStencilFaceState(from: stencilOp),
                stencilReadMask: 0xFFFFFFFF,
                stencilWriteMask: 0xFFFFFFFF,
                depthBias: 0,
                depthBiasSlopeScale: 0,
                depthBiasClamp: 0
            )
        }
    }

    private static func makeStencilFaceState(from stencilOp: StencilOperationDescriptor?) -> WebGPU.GPUStencilFaceState {
        WebGPU.GPUStencilFaceState(
            compare: stencilOp?.compare.toWebGPU ?? .always,
            failOp: stencilOp?.fail.toWebGPU ?? .keep,
            depthFailOp: stencilOp?.depthFail.toWebGPU ?? .keep,
            passOp: stencilOp?.pass.toWebGPU ?? .keep
        )
    }
}

extension WGPURenderPipeline {
    enum InitError: Error {
        case noVertexShader
    }
}

extension IndexPrimitive {
    var toWebGPU: WebGPU.GPUPrimitiveTopology {
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
    var toWebGPU: WebGPU.GPUVertexFormat {
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
    var toWebGPU: WebGPU.GPUBlendFactor {
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
    var toWebGPU: WebGPU.GPUBlendOperation {
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
    var toWebGPU: WebGPU.GPUCompareFunction {
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
    var toWebGPU: WebGPU.GPUStencilOperation {
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
