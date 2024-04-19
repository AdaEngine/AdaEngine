//
//  VulkanUniformBuffer.swift
//  AdaEngine
//
//  Created by v.prusakov on 3/18/24.
//

#if VULKAN
import CVulkan
import Vulkan

final class VulkanUniformBuffer: VulkanBuffer, UniformBuffer {
    let binding: Int

    init(device: Device, size: Int, backend: VulkanRenderBackend, queueFamilyIndecies: [UInt32], binding: Int) throws {
        self.binding = binding
        try super.init(
            device: device,
            size: size,
            usage: VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT.rawValue,
            backend: backend,
            queueFamilyIndecies: queueFamilyIndecies
        )
    }
}

#endif
