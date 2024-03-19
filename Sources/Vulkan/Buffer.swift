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
    
    public func allocateMemory(memoryTypeIndex: UInt32) throws -> DeviceMemory {
        let requirements = self.memoryRequirements
        
        let allocInfo = VkMemoryAllocateInfo(
            sType: VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
            pNext: nil,
            allocationSize: requirements.size,
            memoryTypeIndex: memoryTypeIndex
        )
        
        return try DeviceMemory(device: self.device, allocateInfo: allocInfo)
    }
    
    public func bindMemory(_ memory: DeviceMemory, offset: Int = 0) throws {
        let result = vkBindBufferMemory(self.device.rawPointer, self.rawPointer, memory.rawPointer, UInt64(offset))
        try vkCheck(result)
    }
    
//    public func copy(from source: UnsafeRawPointer, to dest: UnsafeMutableRawPointer, size: Int) {
//        dest.copyMemory(from: source, byteCount: size)
//    }
    
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
