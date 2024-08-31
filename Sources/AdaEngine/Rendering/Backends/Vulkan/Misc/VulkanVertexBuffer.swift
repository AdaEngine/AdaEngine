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

    init(renderDevice: VulkanRenderDevice, size: Int, queueFamilyIndecies: [UInt32], binding: Int) throws {
        self.binding = binding
        try super.init(
            renderDevice: renderDevice,
            size: size,
            usage: VK_BUFFER_USAGE_VERTEX_BUFFER_BIT.rawValue,
            queueFamilyIndecies: queueFamilyIndecies
        )
    }
}

#endif
