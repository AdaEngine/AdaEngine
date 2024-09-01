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
    private unowned let renderDevice: VulkanRenderDevice
    private let memoryFlags: VkMemoryMapFlags
    private let usage: VkBufferUsageFlags

    var label: String? = ""

    var length: Int {
        return Int(buffer.size)
    }

    init(renderDevice: VulkanRenderDevice, size: Int, usage: VkBufferUsageFlags, queueFamilyIndecies: [UInt32]) throws {
        self.buffer = try Vulkan.Buffer(
            device: renderDevice.device,
            size: size,
            usage: .init(rawValue: usage),
            sharingMode: VK_SHARING_MODE_EXCLUSIVE
        )

        self.usage = usage
        self.memoryFlags = VkMemoryMapFlags(VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT.rawValue | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT.rawValue)
        self.renderDevice = renderDevice
    }

    func contents(_ memory: (UnsafeMutableRawPointer?) -> Void) {
        self.buffer.deviceMemory.readMemoryBlock(flags: self.memoryFlags) { pointer in
            memory(pointer)
        }
    }

    func setData(_ bytes: UnsafeMutableRawPointer, byteCount: Int, offset: Int) {
        self.buffer.deviceMemory.readMemoryBlock(flags: self.memoryFlags) { pointer in
            pointer?.advanced(by: offset)
                .copyMemory(from: bytes, byteCount: byteCount)
        }
    }
}
#endif
