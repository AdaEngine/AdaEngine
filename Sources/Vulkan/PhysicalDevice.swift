//
//  PhysicalDevice.swift
//  
//
//  Created by v.prusakov on 8/11/21.
//

import CVulkan

/// Taked from Godot Engine drivers/vulkan/vulkan_context.cpp
/// - SeeAlso: https://github.com/godotengine/godot
public enum GPUVendor: UInt32, Equatable {
    case amd = 0x1002
    case imgTec = 0x1010
    case nvidia = 0x10DE
    case arm = 0x13B5
    case qualcomm = 0x5143
    case intel = 0x8086
    
    case undefined = 0x0
}

/// Wrapper on Vulkan API
/// Represent GPU device
public final class PhysicalDevice {
    
    /// Pointer to physical device
    public let pointer: VkPhysicalDevice
    
    public var vendor: GPUVendor {
        let vendorId = self.properties.vendorID
        
        return GPUVendor(rawValue: vendorId) ?? .undefined
    }
    
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
    
    public lazy var memoryProperties: VkPhysicalDeviceMemoryProperties = {
        var memory = VkPhysicalDeviceMemoryProperties()
        vkGetPhysicalDeviceMemoryProperties(self.pointer, &memory)
        return memory
    }()
    
    public func getExtensions() throws -> [ExtensionProperties] {
        var count: UInt32 = 0
        
        var result = vkEnumerateDeviceExtensionProperties(self.pointer, nil, &count, nil)
        
        guard result == VK_SUCCESS, count > 0 else {
            throw VKError(code: result, message: "Can't get extensions properties for GPU")
        }
        
        var properties = [VkExtensionProperties](repeating: VkExtensionProperties(), count: Int(count))
        result = vkEnumerateDeviceExtensionProperties(self.pointer, nil, &count, &properties)
        
        try vkCheck(result, "Can't get extensions properties for GPU")
        
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
        
        var items = [VkSurfaceFormatKHR](repeating: VkSurfaceFormatKHR(), count: Int(count))
        result = vkGetPhysicalDeviceSurfaceFormatsKHR(self.pointer, surface.rawPointer, &count, &items)
        
        try vkCheck(result, "Can't get surface formats")
        
        return items
    }
    
    public func presentModes(for surface: Surface) throws -> [VkPresentModeKHR] {
        var count: UInt32 = 0
        var result = vkGetPhysicalDeviceSurfacePresentModesKHR(self.pointer, surface.rawPointer, &count, nil)
        
        guard result == VK_SUCCESS, count > 0 else {
            throw VKError(code: result, message: "Can't get present modes")
        }
        
        var items = [VkPresentModeKHR](repeating: VkPresentModeKHR(0), count: Int(count))
        result = vkGetPhysicalDeviceSurfacePresentModesKHR(self.pointer, surface.rawPointer, &count, &items)
        
        try vkCheck(result, "Can't get present modes")
        
        return items
    }
    
    public func supportSurface(_ surface: Surface, queueFamily: QueueFamilyProperties) throws -> Bool {
        var support: VkBool32 = false
        let result = vkGetPhysicalDeviceSurfaceSupportKHR(self.pointer, queueFamily.index, surface.rawPointer, &support)
        
        try vkCheck(result, "Can't check surface support")
        
        return support.boolValue
    }
    
    public func surfaceCapabilities(for surface: Surface) throws -> VkSurfaceCapabilitiesKHR {
        var capabilities = VkSurfaceCapabilitiesKHR()
        let result = vkGetPhysicalDeviceSurfaceCapabilitiesKHR(self.pointer, surface.rawPointer, &capabilities)
        
        try vkCheck(result, "Cannot get VkSurfaceCapabilitiesKHR")
        
        return capabilities
    }
}

public extension VkPresentModeKHR {
    static let immediate: VkPresentModeKHR = VK_PRESENT_MODE_IMMEDIATE_KHR
    static let mailbox: VkPresentModeKHR = VK_PRESENT_MODE_MAILBOX_KHR
    static let fifo: VkPresentModeKHR = VK_PRESENT_MODE_FIFO_KHR
    static let fifoRelaxed: VkPresentModeKHR = VK_PRESENT_MODE_FIFO_RELAXED_KHR
    static let sharedDemandRefresh: VkPresentModeKHR = VK_PRESENT_MODE_SHARED_DEMAND_REFRESH_KHR
    static let sharedContinuousRefresh: VkPresentModeKHR = VK_PRESENT_MODE_SHARED_CONTINUOUS_REFRESH_KHR
    static let maxEnum: VkPresentModeKHR = VK_PRESENT_MODE_MAX_ENUM_KHR
}

