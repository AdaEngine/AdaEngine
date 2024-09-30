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
        precondition(view.layer is CAMetalLayer, "Surface can init only with CAMetalLayer backed view")
        // We should use unmnanaged opaque pointer to pass it on vkCreateMacOSSurfaceMVK,
        // because Vulkan crashed if we refer to local veriable or using `withUnsafePointer` function.
        // I really thought that isn't correct solution, but it's works..
        let unmanagedLayer = Unmanaged.passRetained(view.layer!).autorelease().toOpaque()
        
        var createInfo = VkMetalSurfaceCreateInfoEXT_Swift()
        createInfo.sType = VK_STRUCTURE_TYPE_METAL_SURFACE_CREATE_INFO_EXT;
        createInfo.pLayer = UnsafeRawPointer(unmanagedLayer)
        
        var surface: VkSurfaceKHR?
        let result = withUnsafePointer(to: &createInfo) { ptr in
            vkCreateMetalSurfaceEXT(vulkan.pointer, OpaquePointer(ptr), nil, &surface)
        }
        
        guard let surface = surface, result == VK_SUCCESS else {
            throw VKError(code: result, message: "Can't create macOS surface")
        }
        
        self.init(vulkan: vulkan, surface: surface)
    }
}

#endif
