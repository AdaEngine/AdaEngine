//
//  Device.swift
//  
//
//  Created by v.prusakov on 8/14/21.
//

import CVulkan

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
            throw VKError(code: result, message: "Cannot create VkDevice for passed GPU and create info")
        }
        
        self.init(pointer)
    }
    
    public convenience init(physicalDevice: PhysicalDevice, createInfo: DeviceCreateInfo) throws {
        
        let queueCreateInfos = createInfo.queueCreateInfo.map { $0.vulkanValue }
        var devicePointer: VkDevice?
        
        var layers = createInfo.layers.map { $0.asCString() }
        var extensions = createInfo.enabledExtensions.map { $0.asCString() }
        
        var info = VkDeviceCreateInfo(
            sType: VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
            pNext: nil,
            flags: UInt32(0),
            queueCreateInfoCount: UInt32(createInfo.queueCreateInfo.count),
            pQueueCreateInfos: queueCreateInfos,
            enabledLayerCount: UInt32(createInfo.layers.count),
            ppEnabledLayerNames: layers,
            enabledExtensionCount: UInt32(createInfo.enabledExtensions.count),
            ppEnabledExtensionNames: extensions,
            pEnabledFeatures: nil
        )
        
        let result = vkCreateDevice(physicalDevice.pointer, &info, nil, &devicePointer)
        
        guard let pointer = devicePointer, result == VK_SUCCESS else {
            throw VKError(code: result, message: "Cannot create VkDevice for passed GPU and create info")
        }
        
        self.init(pointer)
    }
    
    deinit {
        vkDestroyDevice(self.rawPointer, nil)
    }
}
