//
//  DeviceMemory.swift
//  
//
//  Created by v.prusakov on 10/23/21.
//

import CVulkan

public final class DeviceMemory {
    
    public let rawPointer: VkDeviceMemory
    private unowned let device: Device
    
    public let size: Int
    
    init(device: Device, rawPointer: VkDeviceMemory, size: Int) {
        self.rawPointer = rawPointer
        self.device = device
        self.size = size
    }
    
    public init(device: Device, allocateInfo: VkMemoryAllocateInfo) throws {
        var rawPointer: VkDeviceMemory?
        
        let result = withUnsafePointer(to: allocateInfo) { ptr in
            vkAllocateMemory(device.rawPointer, ptr, nil, &rawPointer)
        }
        
        try vkCheck(result)
        
        self.size = Int(allocateInfo.allocationSize)
        self.device = device
        self.rawPointer = rawPointer!
    }
    
    public func map(offset: Int, flags: VkMemoryMapFlags) throws -> UnsafeMutableRawPointer {
        var mutPointer: UnsafeMutableRawPointer?
        let result = vkMapMemory(self.device.rawPointer, self.rawPointer, UInt64(offset), VkDeviceSize(self.size), flags, &mutPointer)
        try vkCheck(result)
        
        return mutPointer!
    }
    
    public func free() {
        vkFreeMemory(self.device.rawPointer, self.rawPointer, nil)
    }
    
    public func unmap() {
        vkUnmapMemory(self.device.rawPointer, self.rawPointer)
    }
}

public extension DeviceMemory {
    static func findMemoryTypeIndex(
        for memoryRequirements: VkMemoryRequirements,
        properties: VkMemoryPropertyFlags,
        in gpu: PhysicalDevice
    ) throws -> UInt32 {
        let memProperties = gpu.memoryProperties
        var typesTuple = memProperties.memoryTypes
        let memoryTypes = convertTupleToArray(tuple: typesTuple, start: &typesTuple.0)
        for index in 0 ..< memProperties.memoryTypeCount {
            if (((memoryRequirements.memoryTypeBits & (1 << index)) != 0) && (memoryTypes[Int(index)].propertyFlags & properties) == properties) {
                return index
            }
        }
        
        throw VKError(code: VK_ERROR_UNKNOWN, message: "Can't find memory type index")
    }
}
