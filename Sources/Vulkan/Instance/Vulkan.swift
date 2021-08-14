//
//  File.swift
//  
//
//  Created by v.prusakov on 8/10/21.
//

import CVulkan

public class Vulkan {
    
    /// Pointer to vulkan instance
    public let pointer: VkInstance
    
    public init(_ createInfo: VkInstanceCreateInfo) throws {
        var instance: VkInstance?
        let result = withUnsafePointer(to: createInfo) { vkCreateInstance($0, nil, &instance) }
        
        if result != VK_SUCCESS {
            throw VKError(code: result, message: "Cannot create Vulkan Instance")
        }
        
        self.pointer = instance!
    }
    
    deinit {
        vkDestroyInstance(self.pointer, nil)
    }
    
    // MARK: - Public
    
    /// Returns array of GPUs
    public func physicalDevices() throws -> [PhysicalDevice] {
        var count: UInt32 = 0
        var result =
            vkEnumeratePhysicalDevices(self.pointer, &count, nil)
        
        guard result == VK_SUCCESS, count > 0 else {
            throw VKError(code: result, message: "Cannot get physical devices")
        }
        
        var devices = [VkPhysicalDevice?](repeating: nil, count: Int(count))
        
        result = vkEnumeratePhysicalDevices(self.pointer, &count, &devices)
        
        guard result == VK_SUCCESS else {
            throw VKError(code: result, message: "Cannot get physical devices")
        }
        
        return devices.compactMap { $0 }.map(PhysicalDevice.init)
    }
}

public extension Vulkan {
    
    convenience init(info: InstanceCreateInfo) throws {
        
        let layerNames = info.enabledLayerNames.map { $0.asCString() }
        let ppEnabledLayerNames = layerNames.withContiguousStorageIfAvailable { $0 }
        
        let extensions = info.enabledExtensionNames.map { $0.asCString() }
        let ppEnabledExtensionNames = extensions.withContiguousStorageIfAvailable { $0 }
        
        let appInfo = info.applicationInfo.flatMap { info in
            withUnsafePointer(to: info, { $0 })
        }
        
        var createInfo = VkInstanceCreateInfo()
        createInfo.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO
        createInfo.enabledLayerCount = UInt32(layerNames.count)
        createInfo.ppEnabledLayerNames = ppEnabledLayerNames?.baseAddress
        createInfo.enabledExtensionCount = UInt32(extensions.count)
        createInfo.ppEnabledExtensionNames = ppEnabledExtensionNames?.baseAddress
        createInfo.pApplicationInfo = appInfo
        
        try self.init(createInfo)
    }
}
