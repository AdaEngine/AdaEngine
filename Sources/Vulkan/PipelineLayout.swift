//
//  PipelineLayout.swift
//  
//
//  Created by v.prusakov on 9/18/21.
//

import CVulkan

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
