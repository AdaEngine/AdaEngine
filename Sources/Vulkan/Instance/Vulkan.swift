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
    
    init(_ pointer: VkInstance) {
        self.pointer = pointer
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
    
    convenience init(_ createInfo: VkInstanceCreateInfo) throws {
        var instance: VkInstance?
        let result = withUnsafePointer(to: createInfo) { vkCreateInstance($0, nil, &instance) }
        
        guard let vulkan = instance, result == VK_SUCCESS else {
            throw VKError(code: result, message: "Cannot create Vulkan Instance")
        }
        
        self.init(vulkan)
    }
    
    convenience init(info: InstanceCreateInfo) throws {
        
        let layerNames = info.enabledLayerNames.map { $0.asCString() }
        let extensions = info.enabledExtensionNames.map { $0.asCString() }
        
        let appInfo = info.applicationInfo ?? VkApplicationInfo()
        
        var instance: VkInstance?
        let result = withUnsafePointer(to: appInfo) { infoPtr -> VkResult in
            var createInfo = VkInstanceCreateInfo(
                sType: VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
                pNext: nil,
                flags: 0,
                pApplicationInfo: info.applicationInfo == nil ? nil : infoPtr,
                enabledLayerCount: UInt32(layerNames.count),
                ppEnabledLayerNames: layerNames,
                enabledExtensionCount: UInt32(extensions.count),
                ppEnabledExtensionNames: extensions
            )
               
            return vkCreateInstance(&createInfo, nil, &instance)
        }
        
        guard let vulkan = instance, result == VK_SUCCESS else {
            throw VKError(code: result, message: "Cannot create Vulkan Instance")
        }
        
        self.init(vulkan)
    }
}
