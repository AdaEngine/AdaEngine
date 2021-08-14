//
//  PhysicalDevice.swift
//  
//
//  Created by v.prusakov on 8/11/21.
//

import CVulkan

/// Wrapper on Vulkan API
/// Represent GPU
public final class PhysicalDevice {
    
    /// Pointer to physical device
    public let pointer: VkPhysicalDevice
    
    init(_ pointer: VkPhysicalDevice) {
        self.pointer = pointer
    }
    
    public var properties: VkPhysicalDeviceProperties {
        var properties = VkPhysicalDeviceProperties()
        vkGetPhysicalDeviceProperties(self.pointer, &properties)
        return properties
    }
    
    public var features: VkPhysicalDeviceFeatures {
        var features = VkPhysicalDeviceFeatures()
        vkGetPhysicalDeviceFeatures(self.pointer, &features)
        return features
    }
    
    public var memoryProperties: VkPhysicalDeviceMemoryProperties {
        var memory = VkPhysicalDeviceMemoryProperties()
        vkGetPhysicalDeviceMemoryProperties(self.pointer, &memory)
        return memory
    }
    
    public func getExtensions() throws -> [ExtensionProperties] {
        var count: UInt32 = 0
        
        var result = vkEnumerateDeviceExtensionProperties(self.pointer, nil, &count, nil)
        
        guard result == VK_SUCCESS, count > 0 else {
            throw VKError(code: result, message: "Can't get extensions properties for GPU")
        }
        
        var properties = [VkExtensionProperties](repeating: VkExtensionProperties(), count: Int(count))
        result = vkEnumerateDeviceExtensionProperties(self.pointer, nil, &count, &properties)
        
        guard result == VK_SUCCESS else {
            throw VKError(code: result, message: "Can't get extensions properties for GPU")
        }
        
        return properties.map(ExtensionProperties.init)
    }
    
    public func getQueueFamily() -> [QueueFamilyProperties] {
        var count: UInt32 = 0
        vkGetPhysicalDeviceQueueFamilyProperties(self.pointer, &count, nil)
        
        guard count > 0 else { return [] }
        
        var properties = [VkQueueFamilyProperties](repeating: VkQueueFamilyProperties(), count: Int(count))
        vkGetPhysicalDeviceQueueFamilyProperties(self.pointer, &count, &properties)
        
        return properties.enumerated()
            .map { index, element in
                QueueFamilyProperties(
                    index: UInt32(index),
                    queueFlags: .init(rawValue: element.queueFlags),
                    queueCount: element.queueCount,
                    timestampValidBits: element.timestampValidBits,
                    minImageTransferGranularity: element.minImageTransferGranularity
                )
            }
    }
    
    public func surfaceFormats(for surface: Surface) throws -> [VkSurfaceFormatKHR] {
        var count: UInt32 = 0
        
        var result =
            vkGetPhysicalDeviceSurfaceFormatsKHR(self.pointer, surface.rawPointer, &count, nil)
        
        guard result == VK_SUCCESS, count > 0 else {
            throw VKError(code: result, message: "Can't get surface formats")
        }
        
        var formats = [VkSurfaceFormatKHR](repeating: VkSurfaceFormatKHR(), count: Int(count))
        result = vkGetPhysicalDeviceSurfaceFormatsKHR(self.pointer, surface.rawPointer, &count, &formats)
        
        guard result == VK_SUCCESS else {
            throw VKError(code: result, message: "Can't get surface formats")
        }
        
        return formats
    }
    
    public func supportSurface(_ surface: Surface, queueFamily: QueueFamilyProperties) throws -> Bool {
        var support: VkBool32 = false
        let result = vkGetPhysicalDeviceSurfaceSupportKHR(self.pointer, queueFamily.index, surface.rawPointer, &support)
        
        if result != VK_SUCCESS {
            throw VKError(code: result, message: "Can't check surface support")
        }
        
        return support.boolValue
    }
    
    public func surfaceCapabilities(for surface: Surface) throws -> VkSurfaceCapabilitiesKHR {
        fatalError()
    }
}
