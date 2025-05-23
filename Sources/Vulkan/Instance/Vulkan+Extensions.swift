//
//  File.swift
//  
//
//  Created by v.prusakov on 8/11/21.
//

import CVulkan

public extension VulkanInstance {
    
    /// Get list of all available extensions
    static func getExtensions() throws -> [ExtensionProperties] {
        var extensionsCount: UInt32 = 0
        var result = vkEnumerateInstanceExtensionProperties(nil, &extensionsCount, nil)
        
        guard result == VK_SUCCESS else {
            throw VKError(code: result, message: "Can't get extensions properties")
        }

        if extensionsCount == 0 {
            return []
        }

        var extensionProperties = [VkExtensionProperties](repeating: VkExtensionProperties(),
                                                          count: Int(extensionsCount))
        
        result = vkEnumerateInstanceExtensionProperties(nil, &extensionsCount, &extensionProperties)
        
        guard result == VK_SUCCESS else {
            throw VKError(code: result, message: "Can't get extensions properties")
        }
        
        return extensionProperties.map(ExtensionProperties.init)
    }
    
    /// Get list of all available layer properties
    static func getLayerProperties() throws -> [LayerProperties] {
        var layersCount: UInt32 = 0
        var result = vkEnumerateInstanceLayerProperties(&layersCount, nil)
        
        guard result == VK_SUCCESS else {
            throw VKError(code: result, message: "Cannot get layer properties")
        }

        if layersCount == 0 {
            return []
        }

        var layers = [VkLayerProperties](repeating: VkLayerProperties(), count: Int(layersCount))
        
        result = vkEnumerateInstanceLayerProperties(&layersCount, &layers)
            
        guard result == VK_SUCCESS else {
            throw VKError(code: result, message: "Cannot get layer properties")
        }
        
        return layers.map(LayerProperties.init)
    }
}
