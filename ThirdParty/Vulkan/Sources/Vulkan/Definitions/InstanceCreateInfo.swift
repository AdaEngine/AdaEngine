//
//  InstanceCreateInfo.swift
//  
//
//  Created by v.prusakov on 8/11/21.
//

import CVulkan

public struct InstanceCreateInfo {
    public let applicationInfo: VkApplicationInfo?
    public let enabledLayerNames: [String]
    public let enabledExtensionNames: [String]
    
    public let next: UnsafePointer<Any>?
    public let flags: Int
    
    public init(
        applicationInfo: VkApplicationInfo? = nil,
        enabledLayerNames: [String],
        enabledExtensionNames: [String],
        next: UnsafePointer<Any>? = nil,
        flags: Int = 0
    ) {
        self.applicationInfo = applicationInfo
        self.enabledLayerNames = enabledLayerNames
        self.enabledExtensionNames = enabledExtensionNames
        self.next = next
        self.flags = flags
    }
}
