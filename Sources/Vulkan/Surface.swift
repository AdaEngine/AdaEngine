//
//  Surface.swift
//  
//
//  Created by v.prusakov on 8/11/21.
//

import CVulkan

public final class Surface {
    
    public let rawPointer: VkSurfaceKHR
    unowned let vulkan: VulkanInstance
    
    public init(vulkan: VulkanInstance, surface: VkSurfaceKHR) {
        self.vulkan = vulkan
        self.rawPointer = surface
    }
    
    deinit {
        vkDestroySurfaceKHR(self.vulkan.pointer, self.rawPointer, nil)
    }
    
    public struct CreateInfoFlags: OptionSet {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
    }
}