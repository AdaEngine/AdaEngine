//
//  QueueFamilyProperties.swift
//  
//
//  Created by v.prusakov on 8/11/21.
//

import CVulkan

public struct QueueFamilyProperties {
    public let index: UInt32
    public let queueFlags: Flags
    public let queueCount: UInt32
    public let timestampValidBits: UInt32
    public let minImageTransferGranularity: VkExtent3D
    
    public init(index: UInt32,
                queueFlags: Flags,
                queueCount: UInt32,
                timestampValidBits: UInt32,
                minImageTransferGranularity: VkExtent3D) {
        self.index = index
        self.queueFlags = queueFlags
        self.queueCount = queueCount
        self.timestampValidBits = timestampValidBits
        self.minImageTransferGranularity = minImageTransferGranularity
    }
    
    public struct Flags: OptionSet {
        public let rawValue: UInt32
        
        public init(rawValue: UInt32) {
            self.rawValue = rawValue
        }
        
        public static let graphicsBit = Flags(rawValue: 1 << 0)
        public static let computeBit = Flags(rawValue: 1 << 1)
        public static let transferBit = Flags(rawValue: 1 << 2)
        public static let sparseBindingBit = Flags(rawValue: 1 << 3)
        public static let protectedBit = Flags(rawValue: 1 << 4)
    }
}
