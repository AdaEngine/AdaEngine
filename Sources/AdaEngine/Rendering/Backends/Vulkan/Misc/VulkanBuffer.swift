//
//  VulkanBuffer.swift
//  AdaEngine
//
//  Created by v.prusakov on 3/18/24.
//

#if VULKAN
import CVulkan
import Vulkan

class VulkanBuffer: Buffer {

    private let buffer: Vulkan.Buffer
    private unowned let device: Device

    var label: String? = ""

    var length: Int {
        return Int(buffer.size)
    }

    init(device: Device, size: Int, usage: VkBufferUsageFlags, queueFamilyIndecies: [UInt32]) throws {
        self.buffer = try Vulkan.Buffer(
            device: device,
            size: size,
            usage: .init(rawValue: usage),
            sharingMode: VK_SHARING_MODE_EXCLUSIVE
        )

        self.device = device
    }

    func contents() -> UnsafeMutableRawPointer {
        fatalError()
    }

    func setData(_ bytes: UnsafeMutableRawPointer, byteCount: Int, offset: Int) {
        
    }
}
#endif
