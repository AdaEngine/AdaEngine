//
//  DescriptorPool.swift
//  
//
//  Created by v.prusakov on 10/13/21.
//

import CVulkan

public final class DescriptorPool {
    
    public let rawPointer: VkDescriptorPool
    private unowned let device: Device
    
    public init(device: Device, createInfo: VkDescriptorPoolCreateInfo) throws {
        var rawPointer: VkDescriptorPool?
        
        let result = withUnsafePointer(to: createInfo) { infoPtr in
            vkCreateDescriptorPool(device.rawPointer, infoPtr, nil, &rawPointer)
        }
        
        try vkCheck(result)
        
        self.device = device
        self.rawPointer = rawPointer!
    }
    
    deinit {
        vkDestroyDescriptorPool(self.device.rawPointer, self.rawPointer, nil)
    }
}
