//
//  VulkanIndexBuffer.swift
//  AdaEngine
//
//  Created by v.prusakov on 3/18/24.
//

#if VULKAN
import CVulkan
import Vulkan

final class VulkanIndexBuffer: VulkanBuffer, IndexBuffer {

    let indexFormat: IndexBufferFormat

    init(renderingDevice: VulkanRenderingDevice, size: Int, queueFamilyIndecies: [UInt32], indexFormat: IndexBufferFormat) throws {
        self.indexFormat = indexFormat
        
        try super.init(
            renderingDevice: renderingDevice,
            size: size,
            usage: VK_BUFFER_USAGE_INDEX_BUFFER_BIT.rawValue,
            queueFamilyIndecies: queueFamilyIndecies
        )
    }
}

#endif
