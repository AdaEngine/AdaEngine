//
//  RenderPass.swift
//  
//
//  Created by v.prusakov on 8/17/21.
//

import CVulkan

public class RenderPass {
    
    public let rawPointer: VkRenderPass
    public unowned let device: Device
    
    public init(device: Device, createInfo: VkRenderPassCreateInfo) throws {
        
        var pointer: VkRenderPass?
        
        let result = withUnsafePointer(to: createInfo) { infoPtr in
            vkCreateRenderPass(device.rawPointer, infoPtr, nil, &pointer)
        }
        
        guard let pointer = pointer, result == VK_SUCCESS else {
            throw VKError(code: result, message: "Could not create VkRenderPass")
        }
        
        self.rawPointer = pointer
        self.device = device
    }
    
    deinit {
        vkDestroyRenderPass(self.device.rawPointer, self.rawPointer, nil)
    }
    
}
