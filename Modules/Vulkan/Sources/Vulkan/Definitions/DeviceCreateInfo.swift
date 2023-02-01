//
//  DeviceCreateInfo.swift
//  
//
//  Created by v.prusakov on 8/14/21.
//

import CVulkan

public struct DeviceCreateInfo {
    public let enabledExtensions: [String]
    public let layers: [String]
    public let queueCreateInfo: [DeviceQueueCreateInfo]
    public let enabledFeatures: VkPhysicalDeviceFeatures?

    public init(enabledExtensions: [String], layers: [String], queueCreateInfo: [DeviceQueueCreateInfo], enabledFeatures: VkPhysicalDeviceFeatures?) {
        self.enabledExtensions = enabledExtensions
        self.layers = layers
        self.queueCreateInfo = queueCreateInfo
        self.enabledFeatures = enabledFeatures
    }
}
