//
//  Semaphore.swift
//  
//
//  Created by v.prusakov on 9/10/21.
//

import CVulkan

public final class Semaphore {
    
    public let rawPointer: VkSemaphore
    private unowned let device: Device
    
    public init(device: Device) throws {
        var semaphore: VkSemaphore?
        
        let info = VkSemaphoreCreateInfo(
            sType: VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
            pNext: nil,
            flags: 0
        )
        
        let result = withUnsafePointer(to: info) { ptr in
            vkCreateSemaphore(device.rawPointer, ptr, nil, &semaphore)
        }
        
        try vkCheck(result, "Failed when creating fence")
        
        self.device = device
        self.rawPointer = semaphore!
    }
    
    deinit {
        vkDestroySemaphore(self.device.rawPointer, self.rawPointer, nil)
    }
}
