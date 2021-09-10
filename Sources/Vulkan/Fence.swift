//
//  Fence.swift
//  
//
//  Created by v.prusakov on 9/10/21.
//

import CVulkan

public class Fence {
    
    public let rawPointer: VkFence
    private unowned let device: Device
    
    public init(device: Device) throws {
        var fence: VkFence?
        
        let info = VkFenceCreateInfo(
            sType: VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
            pNext: nil,
            flags: 0
        )
        
        let result = withUnsafePointer(to: info) { ptr in
            vkCreateFence(device.rawPointer, ptr, nil, &fence)
        }
        
        try vkCheck(result, "Failed when creating fence")
        
        self.device = device
        self.rawPointer = fence!
    }
    
    deinit {
        vkDestroyFence(self.device.rawPointer, self.rawPointer, nil)
    }
}
