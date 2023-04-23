//
//  MetalRenderPipeline.swift
//  AdaEngine
//
//  Created by v.prusakov on 1/18/23.
//

#if METAL
import Metal

class MetalRenderPipeline: RenderPipeline {
    
    let descriptor: RenderPipelineDescriptor
    let renderPipeline: MTLRenderPipelineState
    let depthStencilState: MTLDepthStencilState?
    
    init(
        descriptor: RenderPipelineDescriptor,
        renderPipeline: MTLRenderPipelineState,
        depthState: MTLDepthStencilState?
    ) {
        self.descriptor = descriptor
        self.renderPipeline = renderPipeline
        self.depthStencilState = depthState
    }
    
}
#endif
