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
    private unowned let backend: VulkanRenderBackend
    private var localStorage: UnsafeMutableRawPointer
    
    var label: String? = ""

    var length: Int {
        return Int(buffer.size)
    }

    init(device: Device, size: Int, usage: VkBufferUsageFlags, backend: VulkanRenderBackend, queueFamilyIndecies: [UInt32]) throws {
        self.buffer = try Vulkan.Buffer(
            device: device,
            size: size,
            usage: .init(rawValue: usage),
            sharingMode: VK_SHARING_MODE_EXCLUSIVE
        )
        
        self.localStorage = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: 2)
        self.backend = backend
        self.device = device
    }

    func contents() -> UnsafeMutableRawPointer {
        return localStorage
    }

    func setData(_ bytes: UnsafeMutableRawPointer, byteCount: Int, offset: Int) {
        localStorage.copyMemory(
            from: UnsafeRawPointer(bytes).advanced(by: offset),
            byteCount: byteCount
        )
        
        do {
            let transferBuffer = try Vulkan.Buffer(
                device: device,
                size: byteCount,
                usage: [.transferSource],
                sharingMode: VK_SHARING_MODE_EXCLUSIVE
            )
            
            try self.buffer.copyBuffer(
                from: transferBuffer,
                size: byteCount,
                srcOffset: 0,
                dstOffset: offset,
                commandPool: self.backend.context.commandPool
            )
        } catch {
            assertionFailure("Failed to set data for buffer \(label): \(error)")
        }
        

    }
}
#endif
