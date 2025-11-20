//
//  DescriptorSetLayout.swift
//  
//
//  Created by v.prusakov on 10/12/21.
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CVulkan

public final class DescriptorSetLayout {
    public let rawPointer: VkDescriptorSetLayout
    private unowned let device: Device
    
    public init(device: Device, layoutInfo: VkDescriptorSetLayoutCreateInfo) throws {
        
        var rawPointer: VkDescriptorSetLayout?
        
        let result = withUnsafePointer(to: layoutInfo) { ptr in
            vkCreateDescriptorSetLayout(device.rawPointer, ptr, nil, &rawPointer)
        }
        
        try vkCheck(result)
        
        self.device = device
        self.rawPointer = rawPointer!
    }
    
    deinit {
        vkDestroyDescriptorSetLayout(self.device.rawPointer, self.rawPointer, nil)
    }
}
