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
    
    public lazy var memoryRequirements: VkMemoryRequirements = {
        var memoryRequirements = VkMemoryRequirements()
        vkGetImageMemoryRequirements(self.device.rawPointer, self.rawPointer, &memoryRequirements)
        return memoryRequirements
    }()
    
    public init(device: Device, createInfo: VkImageCreateInfo) throws {
        var rawPointer: VkImage?
        
        let result = withUnsafePointer(to: createInfo) { ptr in
            vkCreateImage(device.rawPointer, ptr, nil, &rawPointer)
        }
        
        try vkCheck(result)
        
        self.rawPointer = rawPointer!
        self.device = device
    }
    
    public init(device: Device, pointer: VkImage) {
        self.rawPointer = pointer
        self.device = device
    }
    
    deinit {
        vkDestroyImage(self.device.rawPointer, self.rawPointer, nil)
    }
}
