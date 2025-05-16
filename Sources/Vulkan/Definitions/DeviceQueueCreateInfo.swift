//
//  DeviceQueueCreateInfo.swift
//  
//
//  Created by v.prusakov on 8/14/21.
//

import CVulkan

public struct DeviceQueueCreateInfo {
    public let queueFamilyIndex: UInt32
    public let queuePriorities: [Float]
    public let flags: Flags
    
    public struct Flags: OptionSet, Sendable {
        public let rawValue: UInt32

        public init(rawValue: UInt32) {
            self.rawValue = rawValue
        }

        public static let none = Flags([])
        public static let protectedBit = Flags(rawValue: 1)
    }
    
    public init(
        queueFamilyIndex: UInt32,
        flags: Flags,
        queuePriorities: [Float]
    ) {
        self.queueFamilyIndex = queueFamilyIndex
        self.queuePriorities = queuePriorities
        self.flags = flags
    }
    
    public var vulkanValue: VkDeviceQueueCreateInfo {
        return VkDeviceQueueCreateInfo(
            sType: VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
            pNext: nil,
            flags: self.flags.rawValue,
            queueFamilyIndex: self.queueFamilyIndex,
            queueCount: UInt32(self.queuePriorities.count),
            pQueuePriorities: self.queuePriorities
        )
    }
}
