//
//  File.swift
//  
//
//  Created by v.prusakov on 8/10/21.
//

import CVulkan
//
//class ImageView {
//    init() {
//        vkCreateImageView(<#T##device: VkDevice!##VkDevice!#>, <#T##pCreateInfo: UnsafePointer<VkImageViewCreateInfo>!##UnsafePointer<VkImageViewCreateInfo>!#>, <#T##pAllocator: UnsafePointer<VkAllocationCallbacks>!##UnsafePointer<VkAllocationCallbacks>!#>, <#T##pView: UnsafeMutablePointer<VkImageView?>!##UnsafeMutablePointer<VkImageView?>!#>)
//    }
//}
//
//
//class VirtualDevice {
//    init() {
//        vkCreateDevice(<#T##physicalDevice: VkPhysicalDevice!##VkPhysicalDevice!#>, <#T##pCreateInfo: UnsafePointer<VkDeviceCreateInfo>!##UnsafePointer<VkDeviceCreateInfo>!#>, <#T##pAllocator: UnsafePointer<VkAllocationCallbacks>!##UnsafePointer<VkAllocationCallbacks>!#>, <#T##pDevice: UnsafeMutablePointer<VkDevice?>!##UnsafeMutablePointer<VkDevice?>!#>)
//    }
//}

public final class Device {
    
    public let rawPointer: VkDevice
    
    init(_ rawPointer: VkDevice) {
        self.rawPointer = rawPointer
    }
    
    public convenience init(physicalDevice: PhysicalDevice, createInfo: VkDeviceCreateInfo) throws {
        var devicePointer: VkDevice?
        let result = withUnsafePointer(to: createInfo) { info in
            vkCreateDevice(physicalDevice.pointer, info, nil, &devicePointer)
        }
        
        guard let pointer = devicePointer, result == VK_SUCCESS else {
            throw VKError(code: result, message: "Can't create VkDevice for passed GPU and create info")
        }
        
        self.init(pointer)
    }
    
    deinit {
        vkDestroyDevice(self.rawPointer, nil)
    }
}
