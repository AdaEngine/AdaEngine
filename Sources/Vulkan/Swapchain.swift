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

    public let extent: VkExtent2D
    public let imageFormat: VkFormat
    
    public var framebuffers: [Framebuffer] = []
    
    public var imageViews: [ImageView] = []
    
    public init(device: Device, createInfo: VkSwapchainCreateInfoKHR) throws {
        var swapchain: VkSwapchainKHR?
        
        let result = withUnsafePointer(to: createInfo) { info in
            vkCreateSwapchainKHR(device.rawPointer, info, nil, &swapchain)
        }
        
        try vkCheck(result, "Can't create swapchain")
        
        self.extent = createInfo.imageExtent
        self.imageFormat = createInfo.imageFormat
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
    
    public func acquireNextImage(semaphore: Semaphore, nextImageIndex: inout UInt32) -> VkResult {
        let result = vkAcquireNextImageKHR(
            /*device*/ self.device.rawPointer,
            /*swapchain*/ self.rawPointer,
            /*timeout*/ UInt64.max,
            /*semaphore*/ semaphore.rawPointer,
            /*fence*/ nil,
            /*pImageIndex*/ &nextImageIndex
        )
        
        return result
    }
}
