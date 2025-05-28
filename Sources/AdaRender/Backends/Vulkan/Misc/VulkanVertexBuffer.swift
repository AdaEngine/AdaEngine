//
//  VulkanVertexBuffer.swift
//  AdaEngine
//
//  Created by v.prusakov on 3/18/24.
//

#if VULKAN
import CVulkan
import Vulkan

class VulkanVertexBuffer: VulkanBuffer, VertexBuffer {

    var binding: Int

    init(
        logicalDevice: Device,
        size: Int,
        renderDevice: VulkanRenderDevice,
        queueFamilyIndecies: [UInt32],
        binding: Int
    ) throws {
        self.binding = binding
        try super.init(
            logicalDevice: logicalDevice,
            size: size,
            usage: VK_BUFFER_USAGE_VERTEX_BUFFER_BIT.rawValue,
            renderDevice: renderDevice,
            queueFamilyIndecies: queueFamilyIndecies
        )
    }
}

#endif
