//
//  File.swift
//  
//
//  Created by v.prusakov on 9/10/21.
//

import CVulkan

public final class Buffer {
    
    public let rawPointer: VkBuffer
    private unowned let device: Device
    
    public init(device: Device, usage: Usage) throws {
        
        var buffer: VkBuffer?
        
        let info = VkBufferCreateInfo(
            sType: VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
            pNext: nil,
            flags: 0,
            size: 0,
            usage: usage.rawValue,
            sharingMode: VK_SHARING_MODE_CONCURRENT,
            queueFamilyIndexCount: 0,
            pQueueFamilyIndices: nil
        )
        
        let result = withUnsafePointer(to: info) { ptr in
            vkCreateBuffer(device.rawPointer, ptr, nil, &buffer)
        }
        
        try vkCheck(result)
        
        self.rawPointer = buffer!
        self.device = device
    }
    
    deinit {
        vkDestroyBuffer(self.device.rawPointer, self.rawPointer, nil)
    }
}

public extension Buffer {
    struct Usage: OptionSet {
        public var rawValue: UInt32
        
        public init(rawValue: UInt32) {
            self.rawValue = rawValue
        }
        
        public static let indexBuffer = Usage(rawValue: VK_BUFFER_USAGE_INDEX_BUFFER_BIT.rawValue)
        public static let vertexBuffer = Usage(rawValue: VK_BUFFER_USAGE_VERTEX_BUFFER_BIT.rawValue)
        public static let storageBuffer = Usage(rawValue: VK_BUFFER_USAGE_STORAGE_BUFFER_BIT.rawValue)
    }
}
