//
//  Buffer.swift
//  
//
//  Created by v.prusakov on 9/10/21.
//

import CVulkan

public final class Buffer {
    
    public let rawPointer: VkBuffer
    private unowned let device: Device
    
    public private(set) var size: UInt64
    
    public lazy var memoryRequirements: VkMemoryRequirements = {
        var memoryRequirements = VkMemoryRequirements()
        vkGetBufferMemoryRequirements(self.device.rawPointer, self.rawPointer, &memoryRequirements)
        return memoryRequirements
    }()
    
    public init(device: Device, size: Int, usage: Usage, sharingMode: VkSharingMode) throws {
        
        var buffer: VkBuffer?
        
        self.size = UInt64(size)
        
        let info = VkBufferCreateInfo(
            sType: VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
            pNext: nil,
            flags: 0,
            size: self.size,
            usage: usage.rawValue,
            sharingMode: sharingMode,
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
    
    public func allocateMemory(memoryTypeIndex: UInt32) throws -> VkDeviceMemory {
        let requirements = self.memoryRequirements
        
        var allocInfo = VkMemoryAllocateInfo(
            sType: VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
            pNext: nil,
            allocationSize: requirements.size,
            memoryTypeIndex: memoryTypeIndex
        )
        
        var bufferMemory: VkDeviceMemory?
        let result = vkAllocateMemory(self.device.rawPointer, &allocInfo, nil, &bufferMemory)
        try vkCheck(result)
        
        guard let mem = bufferMemory else {
            throw VKError(code: VK_ERROR_UNKNOWN, message: "Can't allocate buffer memory")
        }
        
        return mem
    }
    
    public func bindMemory(_ memory: VkDeviceMemory, offset: Int = 0) throws {
        let result = vkBindBufferMemory(self.device.rawPointer, self.rawPointer, memory, UInt64(offset))
        try vkCheck(result)
    }
    
    public func mapMemory(_ memory: VkDeviceMemory, offset: Int, flags: VkMemoryMapFlags) throws -> UnsafeMutableRawPointer {
        var mutPointer: UnsafeMutableRawPointer?
        let result = vkMapMemory(self.device.rawPointer, memory, UInt64(offset), self.size, flags, &mutPointer)
        try vkCheck(result)
        
        return mutPointer!
    }
    
    public func copy<T>(from source: T, to dest: UnsafeMutableRawPointer) {
        withUnsafePointer(to: source) { ptr in
            dest.copyMemory(from: ptr, byteCount: Int(self.size))
        }
    }
    
    public func unmapMemory(_ memory: VkDeviceMemory) {
        vkUnmapMemory(self.device.rawPointer, memory)
    }
    
    public func findMemoryTypeIndex(for properties: VkMemoryPropertyFlags, in gpu: PhysicalDevice) throws -> UInt32 {
        let memRequirements = self.memoryRequirements
        let memProperties = gpu.memoryProperties
        var typesTuple = memProperties.memoryTypes
        let memoryTypes = convertTupleToArray(tuple: typesTuple, start: &typesTuple.0)
        for index in 0 ..< memProperties.memoryTypeCount {
            if (((memRequirements.memoryTypeBits & (1 << index)) != 0) && (memoryTypes[Int(index)].propertyFlags & properties) == properties) {
                return index
            }
        }
        
        throw VKError(code: VK_ERROR_UNKNOWN, message: "Can't find memory type index")
    }
    
    public func copyBuffer(
        from source: Buffer,
        size: Int,
        commandPool: CommandPool,
        graphicsQueue: Queue
    ) throws {
        let info = VkCommandBufferAllocateInfo(
            sType: VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
            pNext: nil,
            commandPool: commandPool.rawPointer,
            level: VK_COMMAND_BUFFER_LEVEL_PRIMARY,
            commandBufferCount: 1
        )
        
        let commandBuffer = try CommandBuffer.allocateCommandBuffers(
            for: self.device,
            commandPool: commandPool,
            info: info
        ).first!
        
        try commandBuffer.beginUpdate(flags: .oneTimeSubmit)
        
        var copyRegion = VkBufferCopy(
            srcOffset: 0,
            dstOffset: 0,
            size: VkDeviceSize(size)
        )
        
        vkCmdCopyBuffer(commandBuffer.rawPointer, source.rawPointer, self.rawPointer, 1, &copyRegion)
        
        try commandBuffer.endUpdate()
        
        try graphicsQueue.submit(commandsBuffers: [commandBuffer])
        try graphicsQueue.wait()
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
        
        public static let transferSource = Usage(rawValue: VK_BUFFER_USAGE_TRANSFER_SRC_BIT.rawValue)
        public static let transferDestination = Usage(rawValue: VK_BUFFER_USAGE_TRANSFER_DST_BIT.rawValue)
        
        public static let uniformBuffer = Usage(rawValue: VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT.rawValue)
    }
}


