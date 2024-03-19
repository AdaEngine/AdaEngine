//
//  CommandPool.swift
//  
//
//  Created by v.prusakov on 9/9/21.
//

import CVulkan

final public class CommandPool {
    
    public let rawPointer: VkCommandPool
    private unowned let device: Device
    
    public init(device: Device, queueFamilyIndex: UInt32) throws {
        var commandPool: VkCommandPool?
        
        let info = VkCommandPoolCreateInfo(
            sType: VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
            pNext: nil,
            flags: 0,
            queueFamilyIndex: queueFamilyIndex
        )
        
        let result = withUnsafePointer(to: info) { infoPtr in
            vkCreateCommandPool(device.rawPointer, infoPtr, nil, &commandPool)
        }
        
        guard let pointer = commandPool, result == VK_SUCCESS else {
            throw VKError(code: result, message: "Cannot create CommandPool for passed device")
        }
        self.device = device
        self.rawPointer = pointer
    }
    
    deinit {
        vkDestroyCommandPool(self.device.rawPointer, self.rawPointer, nil)
    }
}
