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
        renderPipeline: WebGPU.RenderPipeline,
        depthState: WebGPU.DepthStencilState?
    ) {
        self.descriptor = descriptor
        self.renderPipeline = renderPipeline
        self.depthStencilState = depthState
    }
    
}
#endif
