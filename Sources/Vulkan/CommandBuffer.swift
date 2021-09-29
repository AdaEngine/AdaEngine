//
//  CommandBuffer.swift
//  
//
//  Created by v.prusakov on 9/9/21.
//

import CVulkan

final public class CommandBuffer {
    
    public enum State {
        case ready
        case recording, recordingEnded
    }
    
    public private(set) var rawPointer: VkCommandBuffer!
    private unowned let device: Device
    private unowned let commandPool: CommandPool
    
    public private(set) var state: State = .ready
    
    public init(device: Device, commandPool: CommandPool, isPrimary: Bool) throws {
        
        var commandBuffer: VkCommandBuffer?
        
        let info = VkCommandBufferAllocateInfo(
            sType: VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
            pNext: nil,
            commandPool: commandPool.rawPointer,
            level: isPrimary ? VK_COMMAND_BUFFER_LEVEL_PRIMARY : VK_COMMAND_BUFFER_LEVEL_SECONDARY,
            commandBufferCount: 1
        )
        
        let result = withUnsafePointer(to: info) { ptr in
            vkAllocateCommandBuffers(device.rawPointer, ptr, &commandBuffer)
        }
        
        guard let pointer = commandBuffer, result == VK_SUCCESS else {
            throw VKError(code: result, message: "Cannot create Command Buffer for passed device")
        }
        self.device = device
        self.rawPointer = pointer
        self.commandPool = commandPool
    }
    
    public init(device: Device, commandPool: CommandPool, pointer: VkCommandBuffer) {
        self.device = device
        self.rawPointer = pointer
        self.commandPool = commandPool
    }
    
    public func beginUpdate() throws {
        let info = VkCommandBufferBeginInfo(
            sType: VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
            pNext: nil,
            flags: VK_COMMAND_BUFFER_USAGE_SIMULTANEOUS_USE_BIT.rawValue,
            pInheritanceInfo: nil
        )
        
        let result = withUnsafePointer(to: info) { ptr in
            vkBeginCommandBuffer(self.rawPointer, ptr)
        }
        
        try vkCheck(result, "Command buffer cannot begins update")
        
        self.state = .recording
    }
    
    public func commandBarrier(_ barrier: VkImageMemoryBarrier) throws {
        vkCmdPipelineBarrier(self.rawPointer, VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT.rawValue, VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT.rawValue, 0, 0, nil, 0, nil, 1, [barrier])
    }
    
    public func draw(vertexCount: Int, instanceCount: Int, firstVertex: Int, firstInstance: Int) {
        vkCmdDraw(self.rawPointer, UInt32(vertexCount), UInt32(instanceCount), UInt32(firstVertex), UInt32(firstInstance))
    }
    
    public func endUpdate() throws {
        let result = vkEndCommandBuffer(self.rawPointer)
        try vkCheck(result, "Command buffer cannot end update")
        
        self.state = .recordingEnded
    }
    
    public func reset() throws {
        let result = vkResetCommandBuffer(self.rawPointer, 0)
        try vkCheck(result)
        
        self.state = .ready
    }
    
    deinit {
        vkFreeCommandBuffers(self.device.rawPointer, self.commandPool.rawPointer, 1, &self.rawPointer)
    }
}
