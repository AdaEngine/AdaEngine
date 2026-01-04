//
//  MetalRenderPipeline.swift
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

        // let fragmentState: WebGPU.FragmentState? = descriptor.fragment.map { shader in
        //     let wgpuShader = shader.compiledShader as! WGPUShader
        //     return WebGPU.FragmentState(
        //         module: wgpuShader.shader,
        //         entryPoint: shader.entryPoint,
        //         constants: [],
        //         targets: [
        //             FragmentStateTarget(
        //                 format: descriptor.colorAttachments[0].format.toWebGPU,
        //             )
        //         ]
        // }

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
                            arrayStride: 0,
                            attributes: [],
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
                depthStencil: nil,
                multisample: MultisampleState(),
                fragment: nil,
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
