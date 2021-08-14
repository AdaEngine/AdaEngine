//
//  Swapchain.swift
//  
//
//  Created by v.prusakov on 8/13/21.
//

import CVulkan

public class Swapchain {
    public let rawPointer: VkSwapchainKHR
    public unowned let device: Device
    
    public init(device: Device, swapchainPoiner: VkSwapchainKHR) {
        self.rawPointer = swapchainPoiner
        self.device = device
    }
    
    public init(device: Device, createInfo: VkSwapchainCreateInfoKHR) throws {
        var swapchain: VkSwapchainKHR?
        
        let result = withUnsafePointer(to: createInfo) { info in
            vkCreateSwapchainKHR(device.rawPointer, info, nil, &swapchain)
        }

        guard let pointer = swapchain, result == VK_SUCCESS else {
            throw VKError(code: result, message: "Can't create swapchain")
        }
        
        self.device = device
        self.rawPointer = pointer
    }
    
    deinit {
        vkDestroySwapchainKHR(self.device.rawPointer, self.rawPointer, nil)
    }
}

struct SwapchainCreateInfo {
    
}
