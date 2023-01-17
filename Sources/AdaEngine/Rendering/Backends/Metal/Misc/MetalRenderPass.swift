//
//  MetalRenderPass.swift
//  
//
//  Created by v.prusakov on 1/18/23.
//

#if METAL
import Metal

class MetalRenderPass: RenderPass {
    
    let descriptor: RenderPassDescriptor
    let renderPass: MTLRenderPassDescriptor
    
    init(descriptor: RenderPassDescriptor, renderPass: MTLRenderPassDescriptor) {
        self.descriptor = descriptor
        self.renderPass = renderPass
    }
}
#endif
