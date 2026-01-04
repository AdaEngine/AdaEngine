//
//  MetalRenderPipeline.swift
//  AdaEngine
//
//  Created by v.prusakov on 1/18/23.
//

#if canImport(WebGPU)
import WebGPU

final class WGPURenderPipeline: RenderPipeline {
    
    let descriptor: RenderPipelineDescriptor
    let renderPipeline: WebGPU.RenderPipeline
    let depthStencilState: WebGPU.DepthStencilState?
    
    init(
        descriptor: RenderPipelineDescriptor,
        device: WebGPU.Device
    ) throws {
        guard let vertex = descriptor.vertex.compiledShader as? WGPUShader else {
            throw InitError.noVertexShader
        }

        let fragmentState = descriptor.fragment.map { shader in

            shader.compiledShader as! WGPUShader
        }

        self.descriptor = descriptor
        renderPipeline = device.createRenderPipeline(
            descriptor: WebGPU.RenderPipelineDescriptor(
                label: descriptor.debugName,
                layout: nil,//PipelineLayout?,
                vertex: VertexState(
                    module: vertex.shader,
                    entryPoint: descriptor.vertex.entryPoint,
                    constants: [

                    ],
                    buffers: [
                        VertexBufferLayout(
                            stepMode: VertexStepMode.vertex,
                            arrayStride: <#T##UInt64#>,
                            attributes: [.init(format: <#T##VertexFormat#>, offset: <#T##UInt64#>, shaderLocation: <#T##UInt32#>)],
                            nextInChain: nil
                        )
                    ]
                ),
                primitive: PrimitiveState(
                    topology: descriptor.primitive.toWebGPU,
                    stripIndexFormat: IndexFormat.uint32,
                    frontFace: FrontFace.cw,
                    cullMode: descriptor.backfaceCulling ? .back : .front,
                    unclippedDepth: false
                ),
                depthStencil: <#T##DepthStencilState?#>,
                multisample: MultisampleState(),
                fragment: <#T##FragmentState?#>,
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
#endif
