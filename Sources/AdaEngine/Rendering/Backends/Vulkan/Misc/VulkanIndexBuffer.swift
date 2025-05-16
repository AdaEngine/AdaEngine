//
//  VulkanIndexBuffer.swift
//  AdaEngine
//
//  Created by v.prusakov on 3/18/24.
//

#if VULKAN
import CVulkan
import Vulkan

final class VulkanIndexBuffer: VulkanBuffer, IndexBuffer, @unchecked Sendable {

    let indexFormat: IndexBufferFormat

    init(
        logicalDevice: Device,
        size: Int,
        renderDevice: VulkanRenderDevice,
        queueFamilyIndecies: [UInt32],
        indexFormat: IndexBufferFormat
    ) throws {
        self.indexFormat = indexFormat
        
        try super.init(
            logicalDevice: logicalDevice,
            size: size,
            usage: VK_BUFFER_USAGE_INDEX_BUFFER_BIT.rawValue,
            renderDevice: renderDevice,
            queueFamilyIndecies: queueFamilyIndecies
        )
    }
}

#endif
