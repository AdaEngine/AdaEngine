//
//  MetalRenderPass.swift
//  
//
//  Created by v.prusakov on 1/18/23.
//

#if METAL
import Metal

class MetalRenderPass: RenderPass {
    
    let renderPass: MTLRenderPassDescriptor
    
    init(renderPass: MTLRenderPassDescriptor) {
        self.renderPass = renderPass
    }
}
#endif
