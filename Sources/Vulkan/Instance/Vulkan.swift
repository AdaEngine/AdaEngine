//
//  VulkanInstance.swift
//
//
//  Created by v.prusakov on 8/10/21.
//

import CVulkan

public final class VulkanInstance {

    /// Pointer to vulkan instance
    public let pointer: VkInstance

    init(_ pointer: VkInstance) {
        self.pointer = pointer
    }

    deinit {
        vkDestroyInstance(self.pointer, nil)
    }

    // MARK: - Public

    /// Returns array of GPUs
    public func physicalDevices() throws -> [PhysicalDevice] {
        var count: UInt32 = 0
        var result =
        vkEnumeratePhysicalDevices(self.pointer, &count, nil)

        guard result == VK_SUCCESS, count > 0 else {
            throw VKError(code: result, message: "Cannot get physical devices")
        }

        var devices = [VkPhysicalDevice?](repeating: nil, count: Int(count))

        result = vkEnumeratePhysicalDevices(self.pointer, &count, &devices)

        guard result == VK_SUCCESS else {
            throw VKError(code: result, message: "Cannot get physical devices")
        }

        return devices.compactMap { $0 }.map(PhysicalDevice.init)
    }
}

public extension VulkanInstance {

    convenience init(_ createInfo: VkInstanceCreateInfo) throws {
        var instance: VkInstance?
        let result = withUnsafePointer(to: createInfo) {
            vkCreateInstance($0, nil, &instance)
        }

        guard let vulkan = instance, result == VK_SUCCESS else {
            throw VKError(code: result, message: "Cannot create Vulkan Instance")
        }

        self.init(vulkan)
    }

    convenience init(info: InstanceCreateInfo) throws {
        let holder = VulkanUtils.TemporaryBufferHolder(label: "VulkanInstance initialization")

        let layers = holder.unsafePointerCopy(collection: info.enabledLayerNames.map {
            holder.unsafePointerCopy(string: $0)
        })

        let extensions = holder.unsafePointerCopy(collection: info.enabledExtensionNames.map {
            holder.unsafePointerCopy(string: $0)
        })

        var instance: VkInstance?

        var createInfo = VkInstanceCreateInfo(
            sType: VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
            pNext: nil,
            flags: info.flags,
            pApplicationInfo: info.applicationInfo,
            enabledLayerCount: UInt32(info.enabledLayerNames.count),
            ppEnabledLayerNames: layers,
            enabledExtensionCount: UInt32(info.enabledExtensionNames.count),
            ppEnabledExtensionNames: extensions
        )

        let result = vkCreateInstance(&createInfo, nil, &instance)

        guard let vulkan = instance, result == VK_SUCCESS else {
            throw VKError(code: result, message: "Cannot create Vulkan Instance")
        }

        self.init(vulkan)
    }
}
