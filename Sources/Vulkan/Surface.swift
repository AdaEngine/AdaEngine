//
//  Surface.swift
//  
//
//  Created by v.prusakov on 8/11/21.
//

import CVulkan

#if os(macOS)
import AppKit
#endif

public final class Surface {
    
    public let rawPointer: VkSurfaceKHR
    unowned let vulkan: Vulkan
    
    public init(vulkan: Vulkan, surface: VkSurfaceKHR) {
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

#if os(macOS)

public extension Surface {
    convenience init(
        vulkan: Vulkan,
        view: NSView
    ) throws {
        
        var info = VkMacOSSurfaceCreateInfoMVK(
            sType: VK_STRUCTURE_TYPE_MACOS_SURFACE_CREATE_INFO_MVK,
            pNext: nil,
            flags: 0,
            pView: withUnsafePointer(to: view, { $0 }))
        
        var surface: VkSurfaceKHR?
        let result = vkCreateMacOSSurfaceMVK(vulkan.pointer, &info, nil, &surface)
        
        guard let surface = surface, result == VK_SUCCESS else {
            throw VKError(code: result, message: "Can't create macOS surface")
        }
        
        self.init(vulkan: vulkan, surface: surface)
    }
}

#endif
