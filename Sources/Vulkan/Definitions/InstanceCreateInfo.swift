//
//  InstanceCreateInfo.swift
//  
//
//  Created by v.prusakov on 8/11/21.
//

import CVulkan

public struct InstanceCreateInfo {
    public var applicationInfo:  UnsafePointer<VkApplicationInfo>!
    public var enabledLayerNames: [String]
    public var enabledExtensionNames: [String]

    public var next: UnsafePointer<Any>?
    public var flags: UInt32

    public init(
        applicationInfo: UnsafePointer<VkApplicationInfo>!,
        enabledLayerNames: [String],
        enabledExtensionNames: [String],
        next: UnsafePointer<Any>? = nil,
        flags: UInt32 = 0
    ) {
        self.applicationInfo = applicationInfo
        self.enabledLayerNames = enabledLayerNames
        self.enabledExtensionNames = enabledExtensionNames
        self.next = next
        self.flags = flags
    }
}
