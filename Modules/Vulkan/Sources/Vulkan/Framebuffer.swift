//
//  Framebuffer.swift
//  
//
//  Created by v.prusakov on 8/17/21.
//

import CVulkan

public final class Framebuffer {
    
    public let rawPointer: VkFramebuffer
    public unowned let device: Device
    
    public init(device: Device, createInfo: VkFramebufferCreateInfo) throws {
        var pointer: VkFramebuffer?
        
        let result = withUnsafePointer(to: createInfo) { infoPtr in
            vkCreateFramebuffer(device.rawPointer, infoPtr, nil, &pointer)
        }
        
        guard let pointer = pointer, result == VK_SUCCESS else {
            throw VKError(code: result, message: "Could not create VkFramebuffer")
        }
        
        self.rawPointer = pointer
        self.device = device
    }
    
    deinit {
        vkDestroyFramebuffer(self.device.rawPointer, self.rawPointer, nil)
    }
}
