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

// TODO: Make common surface for Metal family

#if os(iOS) || os(tvOS) || os(macOS)

import MetalKit

public extension Surface {
    convenience init(
        vulkan: VulkanInstance,
        view: MTKView
    ) throws {
        guard let layer = view.layer as? CAMetalLayer else {
            throw VKError(code: VK_ERROR_INITIALIZATION_FAILED, message: "Can't cast layer to CAMetalLayer")
        }
        
        var createInfo = VkMetalSurfaceCreateInfoEXT()
        createInfo.sType = VK_STRUCTURE_TYPE_METAL_SURFACE_CREATE_INFO_EXT;
        createInfo.pLayer = layer
        
        var surface: VkSurfaceKHR?
        let result = withUnsafePointer(to: &createInfo) { ptr in
            vkCreateMetalSurfaceEXT(vulkan.pointer, ptr, nil, &surface)
        }
        
        guard let surface = surface, result == VK_SUCCESS else {
            throw VKError(code: result, message: "Can't create macOS surface")
        }
        
        self.init(vulkan: vulkan, surface: surface)
    }
}

#endif
