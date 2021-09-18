//
//  RenderPipeline.swift
//  
//
//  Created by v.prusakov on 9/10/21.
//

import CVulkan

public final class RenderPipeline {
    
    public let rawPointer: VkPipeline
    private unowned let device: Device
    private let pipelineLayout: PipelineLayout
    
    public init(device: Device, pipelineLayout: PipelineLayout, graphicCreateInfo: VkGraphicsPipelineCreateInfo) throws {
        var pointer: VkPipeline?
        
        let result = withUnsafePointer(to: graphicCreateInfo) { ptr in
            vkCreateGraphicsPipelines(device.rawPointer, nil, 1, ptr, nil, &pointer)
        }
        
        try vkCheck(result)
        
        self.rawPointer = pointer!
        self.device = device
        self.pipelineLayout = pipelineLayout
    }
    
    
    deinit {
        vkDestroyPipeline(self.device.rawPointer, self.rawPointer, nil)
    }
}
