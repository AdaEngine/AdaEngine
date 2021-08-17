//
//  File.swift
//  
//
//  Created by v.prusakov on 8/10/21.
//

import CVulkan

public class ImageView {
    
    public let rawPointer: VkImageView!
    public unowned let device: Device
    
    public init(device: Device, info: VkImageViewCreateInfo) throws {
        var pointer: VkImageView?
        
        let result = withUnsafePointer(to: info) { infoPtr -> VkResult in
            vkCreateImageView(device.rawPointer, infoPtr, nil, &pointer)
        }
        
        guard let imageView = pointer, result == VK_SUCCESS else {
            throw VKError(code: result, message: "Could not create VkImageView")
        }
        
        self.rawPointer = imageView
        self.device = device
    }
    
    deinit {
        vkDestroyImageView(self.device.rawPointer, self.rawPointer, nil)
    }
}

