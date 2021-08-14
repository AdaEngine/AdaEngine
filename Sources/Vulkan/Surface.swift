//
//  Surface.swift
//  
//
//  Created by v.prusakov on 8/11/21.
//

import CVulkan

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

import AppKit

public extension Surface {
    convenience init(
        vulkan: Vulkan,
        view: NSView
    ) throws {
        precondition(view.layer is CAMetalLayer, "Surface can init only with CAMetalLayer backed view")
        // We should use unmnanaged opaque pointer to pass it on vkCreateMacOSSurfaceMVK,
        // because Vulkan crashed if we refer to local veriable or using `withUnsafePointer` function.
        // I really thought that isn't correct solution, but it's works..
        let unmanagedView = Unmanaged.passRetained(view).autorelease().toOpaque()
        
        var info = VkMacOSSurfaceCreateInfoMVK(
            sType: VK_STRUCTURE_TYPE_MACOS_SURFACE_CREATE_INFO_MVK,
            pNext: nil,
            flags: 0,
            pView: unmanagedView)
        
        var surface: VkSurfaceKHR?
        let result = vkCreateMacOSSurfaceMVK(vulkan.pointer, &info, nil, &surface)
        
        guard let surface = surface, result == VK_SUCCESS else {
            throw VKError(code: result, message: "Can't create macOS surface")
        }
        
        self.init(vulkan: vulkan, surface: surface)
    }
}

#endif

#if os(iOS) || os(tvOS)

import UIKit

public extension Surface {
    convenience init(
        vulkan: Vulkan,
        view: UIView
    ) throws {
        precondition(view.layer is CAMetalLayer, "Surface can init only with CAMetalLayer backed view")
        
        // We should use unmnanaged opaque pointer to pass it on vkCreateIOSSurfaceMVK,
        // because Vulkan crashed if we refer to local veriable or using `withUnsafePointer` function.
        // I really thought that isn't correct solution, but it's works..
        let unmanagedView = Unmanaged.passRetained(view).autorelease().toOpaque()
        
        var info = VkIOSSurfaceCreateInfoMVK(
            sType: VK_STRUCTURE_TYPE_IOS_SURFACE_CREATE_INFO_MVK,
            pNext: nil,
            flags: 0,
            pView: unmanagedView)
        
        var surface: VkSurfaceKHR?
        let result = vkCreateIOSSurfaceMVK(vulkan.pointer, &info, nil, &surface)
        
        guard let surface = surface, result == VK_SUCCESS else {
            throw VKError(code: result, message: "Can't create surface for UIView")
        }
        
        self.init(vulkan: vulkan, surface: surface)
    }
}

#endif

