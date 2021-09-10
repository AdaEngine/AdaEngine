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
        
        try vkCheck(result, "Can't create swapchain")
        
        self.device = device
        self.rawPointer = swapchain!
    }
    
    deinit {
        vkDestroySwapchainKHR(self.device.rawPointer, self.rawPointer, nil)
    }
    
    public func getImages() throws -> [VkImage] {
        var count: UInt32 = 0
        var result = vkGetSwapchainImagesKHR(self.device.rawPointer, self.rawPointer, &count, nil)
        
        guard result == VK_SUCCESS, count > 0 else {
            throw VKError(code: result, message: "Failed to get images from swapchain")
        }
        
        var images = [VkImage?](repeating: nil, count: Int(count))
        result = vkGetSwapchainImagesKHR(self.device.rawPointer, self.rawPointer, &count, &images)
        
        try vkCheck(result, "Failed to get images from swapchain")
        
        return images.compactMap { $0 }
    }
}
