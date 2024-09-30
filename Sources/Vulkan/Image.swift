//
//  Image.swift
//  
//
//  Created by v.prusakov on 10/23/21.
//

import CVulkan

public final class Image {
    
    public let rawPointer: VkImage
    private unowned let device: Device
    public let memory: DeviceMemory
    
    public init(device: Device, createInfo: VkImageCreateInfo) throws {
        var rawPointer: VkImage?
        
        let result = withUnsafePointer(to: createInfo) { ptr in
            vkCreateImage(device.rawPointer, ptr, nil, &rawPointer)
        }
        
        try vkCheck(result)

        var memoryRequirements = VkMemoryRequirements()
        vkGetImageMemoryRequirements(device.rawPointer, rawPointer, &memoryRequirements)

        let allocationInfo = VkMemoryAllocateInfo(
            sType: VK_STRUCTURE_TYPE_DEDICATED_ALLOCATION_IMAGE_CREATE_INFO_NV,
            pNext: nil,
            allocationSize: memoryRequirements.size,
            memoryTypeIndex: 0
        )

        self.memory = try DeviceMemory(device: device, allocateInfo: allocationInfo)
        try self.memory.bindImageMemory(rawPointer)

        self.rawPointer = rawPointer!
        self.device = device
    }
    
    deinit {
        vkDestroyImage(self.device.rawPointer, self.rawPointer, nil)
    }
}
