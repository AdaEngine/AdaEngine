//
//  DescriptorSet.swift
//  
//
//  Created by v.prusakov on 10/19/21.
//

import CVulkan

public class DescriptorSet {
    
    public let rawPointer: VkDescriptorSet
    private unowned let device: Device
    
    init(device: Device, rawPointer: VkDescriptorSet) {
        self.device = device
        self.rawPointer = rawPointer
    }
    
    public static func allocateSets(device: Device, info: VkDescriptorSetAllocateInfo, count: Int) throws -> [DescriptorSet] {
        var descriptorSets: [VkDescriptorSet?] = [VkDescriptorSet?].init(repeating: nil, count: count)
        let result = withUnsafePointer(to: info) { ptr in
            vkAllocateDescriptorSets(device.rawPointer, ptr, &descriptorSets)
        }
        
        try vkCheck(result)
        
        return descriptorSets.compactMap { pointer in
            guard let ptr = pointer else { return nil }
            return DescriptorSet(device: device, rawPointer: ptr)
        }
    }
    
}
