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
    
    public func beginUpdate(flags: BeginFlags = .simultaneousUse) throws {
        let info = VkCommandBufferBeginInfo(
            sType: VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
            pNext: nil,
            flags: flags.rawValue,
            pInheritanceInfo: nil
        )
        
        let result = withUnsafePointer(to: info) { ptr in
            vkBeginCommandBuffer(self.rawPointer, ptr)
        }
        
        try vkCheck(result, "Command buffer cannot begins update")
        self.state = .recording
    }
    
    public func endUpdate() throws {
        let result = vkEndCommandBuffer(self.rawPointer)
        try vkCheck(result, "Command buffer cannot end update")
        self.state = .recordingEnded
    }

    public func beginRenderPass(
        framebuffer: VKFramebuffer,
        renderArea: VkRect2D,
        clearColors: [VkClearValue]
    ) {
        clearColors.withUnsafeBufferPointer { ptr in
            let info = VkRenderPassBeginInfo(
                sType: VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
                pNext: nil,
                renderPass: self.rawPointer,
                framebuffer: framebuffer.rawPointer,
                renderArea: renderArea,
                clearValueCount: UInt32(clearColors.count),
                pClearValues: ptr.baseAddress
            )

            return withUnsafePointer(to: info) { ptr in
                vkCmdBeginRenderPass(self.rawPointer, ptr, VK_SUBPASS_CONTENTS_INLINE)
            }
        }
    }

    @inline(__always)
    public func endRenderPass() {
        vkCmdEndRenderPass(self.rawPointer)
    }

    @inline(__always)
    public func setViewport(_ viewports: [VkViewport]) {
        viewports.withUnsafeBufferPointer { ptr in
            vkCmdSetViewport(self.rawPointer, 0, UInt32(viewports.count), ptr.baseAddress)
        }
    }

    @inline(__always)
    public func setScissor(_ scissors: [VkRect2D]) {
        scissors.withUnsafeBufferPointer { ptr in
            vkCmdSetScissor(self.rawPointer, 0, UInt32(scissors.count), ptr.baseAddress)
        }
    }

    @inline(__always)
    public func setCullMode(_ mode: VkCullModeFlags) {
        vkCmdSetCullMode(self.rawPointer, mode)
    }

    @inline(__always)
    public func setFrontFacing(_ frontFace: VkFrontFace) {
        vkCmdSetFrontFace(self.rawPointer, frontFace)
    }

    @inline(__always)
    public func setLineWidth(_ lineWidth: Float) {
        vkCmdSetLineWidth(self.rawPointer, lineWidth)
    }
    
    @inline(__always)
    public func bindRenderPipeline(_ pipeline: RenderPipeline) {
        vkCmdBindPipeline(self.rawPointer, VK_PIPELINE_BIND_POINT_GRAPHICS, pipeline.rawPointer)
    }

    @inline(__always)
    public func bindVertexBuffers(
        _ buffers: [Buffer],
        firstBinding: Int,
        bindingCount: Int,
        offsets: [UInt64]
    ) {
        var vertexBuffers: [VkBuffer?] = buffers.map(\.rawPointer)
        var offsets: [UInt64] = offsets
        vkCmdBindVertexBuffers(
            self.rawPointer,
            UInt32(firstBinding),
            UInt32(bindingCount), 
            &vertexBuffers,
            &offsets
        )
    }

    @inline(__always)
    public func bindPrimitiveTopology(_ topology: VkPrimitiveTopology) {
        vkCmdSetPrimitiveTopology(self.rawPointer, topology)
    }

    @inline(__always)
    public func bindIndexBuffer(_ buffer: Buffer, offset: UInt64, indexType: VkIndexType) {
        vkCmdBindIndexBuffer(self.rawPointer, buffer.rawPointer, offset, indexType)
    }
    
    @inline(__always)
    public func bindDescriptorSet(
        pipelineBindPoint: VkPipelineBindPoint,
        layout: PipelineLayout,
        firstSet: UInt32,
        descriptorSets: [DescriptorSet],
        dynamicOffsets: [UInt32]? = nil
    ) {
        var descriptorSets: [VkDescriptorSet?] = descriptorSets.map(\.rawPointer)
        vkCmdBindDescriptorSets(
            self.rawPointer,
            pipelineBindPoint,
            layout.rawPointer,
            firstSet,
            UInt32(descriptorSets.count),
            &descriptorSets,
            UInt32(dynamicOffsets?.count ?? 0),
            dynamicOffsets
        )
    }

    @inline(__always)
    public func commandBarrier(_ barrier: VkImageMemoryBarrier) throws {
        vkCmdPipelineBarrier(self.rawPointer, VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT.rawValue, VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT.rawValue, 0, 0, nil, 0, nil, 1, [barrier])
    }

    @inline(__always)
    public func draw(vertexCount: Int, instanceCount: Int, firstVertex: Int, firstInstance: Int) {
        vkCmdDraw(self.rawPointer, UInt32(vertexCount), UInt32(instanceCount), UInt32(firstVertex), UInt32(firstInstance))
    }

    @inline(__always)
    public func drawIndexed(indexCount: Int, instanceCount: Int, firstIndex: Int, vertexOffset: Int, firstInstance: Int) {
        vkCmdDrawIndexed(
            self.rawPointer,
            UInt32(indexCount),
            UInt32(instanceCount),
            UInt32(firstIndex),
            Int32(vertexOffset),
            UInt32(firstInstance)
        )
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

public extension CommandBuffer {
    static func allocateCommandBuffers(for device: Device, commandPool: CommandPool, info: VkCommandBufferAllocateInfo) throws -> [CommandBuffer] {
        var commandBuffers = [VkCommandBuffer?].init(repeating: nil, count: Int(info.commandBufferCount))
        
        let result = withUnsafePointer(to: info) { ptr in
            vkAllocateCommandBuffers(device.rawPointer, ptr, &commandBuffers)
        }
        
        try vkCheck(result)
        
        return commandBuffers.compactMap { ptr in
            guard let ptr = ptr else { return nil }
            return CommandBuffer(device: device, commandPool: commandPool, pointer: ptr)
        }
    }
    
    struct BeginFlags: OptionSet {
        public var rawValue: UInt32
        
        public init(rawValue: UInt32) {
            self.rawValue = rawValue
        }
        
        public static let oneTimeSubmit = BeginFlags(rawValue: VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT.rawValue)
        public static let renderPassContinue = BeginFlags(rawValue: VK_COMMAND_BUFFER_USAGE_RENDER_PASS_CONTINUE_BIT.rawValue)
        public static let simultaneousUse = BeginFlags(rawValue: VK_COMMAND_BUFFER_USAGE_SIMULTANEOUS_USE_BIT.rawValue)
        public static let flagBitsMaxEnum = BeginFlags(rawValue: VK_COMMAND_BUFFER_USAGE_FLAG_BITS_MAX_ENUM.rawValue)
    }
}