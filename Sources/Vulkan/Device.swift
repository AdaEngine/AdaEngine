//
//  Device.swift
//  
//
//  Created by v.prusakov on 8/14/21.
//

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
        
        let queueCreateInfos = createInfo.queueCreateInfo.map { $0.vulkanValue }
        var devicePointer: VkDevice?
        
        let layers = createInfo.layers.map { $0.toPointer() }
        let extensions = createInfo.enabledExtensions.map { $0.toPointer() }
        let features = createInfo.enabledFeatures ?? VkPhysicalDeviceFeatures()
        
        let result: VkResult = withUnsafePointer(to: features) { featuresPtr in
            queueCreateInfos.withUnsafeBufferPointer { queuesPtr in
                extensions.withUnsafeBufferPointer { extPtr in
                    layers.withUnsafeBufferPointer { layersPtr in
                        var info = VkDeviceCreateInfo(
                            sType: VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
                            pNext: nil,
                            flags: 0,
                            queueCreateInfoCount: UInt32(createInfo.queueCreateInfo.count),
                            pQueueCreateInfos: queuesPtr.baseAddress,
                            enabledLayerCount: UInt32(createInfo.layers.count),
                            ppEnabledLayerNames: layersPtr.baseAddress,
                            enabledExtensionCount: UInt32(createInfo.enabledExtensions.count),
                            ppEnabledExtensionNames: extPtr.baseAddress,
                            pEnabledFeatures: createInfo.enabledFeatures != nil ? featuresPtr : nil
                        )

                        return vkCreateDevice(physicalDevice.pointer, &info, nil, &devicePointer)
                    }
                }
            }
        }

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
    
    deinit {
        vkDestroyDevice(self.rawPointer, nil)
    }
}
