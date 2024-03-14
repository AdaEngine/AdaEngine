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
        
        public static let graphicsBit = Flags(rawValue: VK_QUEUE_GRAPHICS_BIT.rawValue)
        public static let computeBit = Flags(rawValue: VK_QUEUE_COMPUTE_BIT.rawValue)
        public static let transferBit = Flags(rawValue: VK_QUEUE_TRANSFER_BIT.rawValue)
        public static let sparseBindingBit = Flags(rawValue: VK_QUEUE_SPARSE_BINDING_BIT.rawValue)
        public static let protectedBit = Flags(rawValue: VK_QUEUE_PROTECTED_BIT.rawValue)
        public static let videoDecodeBitKHR = Flags(rawValue: VK_QUEUE_VIDEO_DECODE_BIT_KHR.rawValue)
        public static let videoEncodeBitKHR = Flags(rawValue: VK_QUEUE_VIDEO_ENCODE_BIT_KHR.rawValue)
        public static let opticalFlowBitNV = Flags(rawValue: VK_QUEUE_OPTICAL_FLOW_BIT_NV.rawValue)
        public static let bitsMaxEnum = Flags(rawValue: VK_QUEUE_FLAG_BITS_MAX_ENUM.rawValue)
    }
}
