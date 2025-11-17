//
//  Device.swift
//
//
//  Created by v.prusakov on 8/14/21.
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CVulkan

public final class Device {

    public let rawPointer: VkDevice

    init(_ rawPointer: VkDevice) {
        self.rawPointer = rawPointer
    }

    public convenience init(physicalDevice: PhysicalDevice, createInfo: VkDeviceCreateInfo) throws {
        var devicePointer: VkDevice?
        let result = withUnsafePointer(to: createInfo) { info in
            vkCreateDevice(physicalDevice.pointer, info, nil, &devicePointer)
        }

        guard let pointer = devicePointer, result == VK_SUCCESS else {
            throw VKError(code: result, message: "Cannot create VkDevice for passed GPU and create info")
        }

        self.init(pointer)
    }

    public convenience init(physicalDevice: PhysicalDevice, createInfo: DeviceCreateInfo) throws {
        let holder = VulkanUtils.TemporaryBufferHolder(label: "Device initialization")

        let queueCreateInfos = holder.unsafePointerCopy(collection: createInfo.queueCreateInfo.map { $0.vulkanValue })
        var devicePointer: VkDevice?

        let layers = holder.unsafePointerCopy(collection: createInfo.layers.map {
            holder.unsafePointerCopy(string: $0)
        })

        let extensions = holder.unsafePointerCopy(collection: createInfo.enabledExtensions.map {
            holder.unsafePointerCopy(string: $0)
        })

        let features = holder.unsafePointerCopy(from: createInfo.enabledFeatures ?? VkPhysicalDeviceFeatures())

        var info = VkDeviceCreateInfo(
            sType: VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
            pNext: nil,
            flags: 0,
            queueCreateInfoCount: UInt32(createInfo.queueCreateInfo.count),
            pQueueCreateInfos: queueCreateInfos,
            enabledLayerCount: UInt32(createInfo.layers.count),
            ppEnabledLayerNames: layers,
            enabledExtensionCount: UInt32(createInfo.enabledExtensions.count),
            ppEnabledExtensionNames: extensions,
            pEnabledFeatures: features
        )

        let result = vkCreateDevice(physicalDevice.pointer, &info, nil, &devicePointer)

        guard let pointer = devicePointer, result == VK_SUCCESS else {
            throw VKError(code: result, message: "Cannot create VkDevice for passed GPU and create info")
        }

        self.init(pointer)
    }

    public func waitIdle() throws {
        let result = vkDeviceWaitIdle(self.rawPointer)
        try vkCheck(result, "Device waiting idle error")
    }

    public func getQueue(at index: Int) -> Queue? {
        return Queue(device: self, index: UInt32(index))
    }
    
    public func getCommandBuffer(commandPool: CommandPool) throws -> CommandBuffer {
        let info = VkCommandBufferAllocateInfo(
            sType: VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
            pNext: nil,
            commandPool: commandPool.rawPointer,
            level: VK_COMMAND_BUFFER_LEVEL_PRIMARY,
            commandBufferCount: 1
        )
        
        let commandBuffer = try CommandBuffer.allocateCommandBuffers(
            for: self,
            commandPool: commandPool,
            info: info
        ).first!
        
        return commandBuffer
    }

    deinit {
        vkDestroyDevice(self.rawPointer, nil)
    }
}
