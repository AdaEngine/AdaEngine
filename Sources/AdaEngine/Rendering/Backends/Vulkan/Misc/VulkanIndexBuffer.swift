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

    init(device: Device, size: Int, backend: VulkanRenderBackend, queueFamilyIndecies: [UInt32], indexFormat: IndexBufferFormat) throws {
        self.indexFormat = indexFormat
        
        try super.init(
            device: device,
            size: size,
            usage: VK_BUFFER_USAGE_INDEX_BUFFER_BIT.rawValue,
            backend: backend,
            queueFamilyIndecies: queueFamilyIndecies
        )
    }
}

#endif
