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
    
    public init(device: Device, renderPass: RenderPass) throws {
        
        var pipeline: VkPipeline?
        
        let info = VkGraphicsPipelineCreateInfo(
            sType: VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
            pNext: nil,
            flags: 0,
            stageCount: 0,
            pStages: nil,
            pVertexInputState: nil,
            pInputAssemblyState: nil,
            pTessellationState: nil,
            pViewportState: nil,
            pRasterizationState: nil,
            pMultisampleState: nil,
            pDepthStencilState: nil,
            pColorBlendState: nil,
            pDynamicState: nil,
            layout: nil,
            renderPass: renderPass.rawPointer,
            subpass: 0,
            basePipelineHandle: nil,
            basePipelineIndex: 0
        )
        
        let result = withUnsafePointer(to: info) { ptr in
            vkCreateGraphicsPipelines(device.rawPointer, nil, 1, ptr, nil, &pipeline)
        }
        
        try vkCheck(result)
        
        self.rawPointer = pipeline!
        self.device = device
    }
    
    deinit {
        vkDestroyPipeline(self.device.rawPointer, self.rawPointer, nil)
    }
}

public final class PipelineLayout {
    
    public let rawPointer: VkPipelineLayout
    private unowned let device: Device
    
    public init(device: Device) throws {
        
        var pointer: VkPipelineLayout?
        
        let info = VkPipelineLayoutCreateInfo(
            sType: VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
            pNext: nil,
            flags: 0,
            setLayoutCount: 0,
            pSetLayouts: nil,
            pushConstantRangeCount: 0,
            pPushConstantRanges: nil
        )
        
        let result = withUnsafePointer(to: info) { ptr in
            vkCreatePipelineLayout(device.rawPointer, ptr, nil, &pointer)
        }
        
        try vkCheck(result)
        
        self.rawPointer = pointer!
        self.device = device
    }
    
    deinit {
        vkDestroyPipelineLayout(self.device.rawPointer, self.rawPointer, nil)
    }
}
