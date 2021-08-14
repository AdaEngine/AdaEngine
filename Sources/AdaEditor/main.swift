//
//  File.swift
//  
//
//  Created by v.prusakov on 8/10/21.
//

import AdaEngine
import Vulkan
import CVulkan
import CSDL2

#if os(macOS)

import AppKit
import MetalKit

let app = NSApplication.shared

class AppDelegate: NSObject, NSApplicationDelegate {
    let window = NSWindow(contentRect: NSMakeRect(200, 200, 800, 600),
                          styleMask: [.titled, .closable, .resizable],
                          backing: .buffered,
                          defer: false,
                          screen: NSScreen.main)
    
    var vulkan: Vulkan?

    func applicationDidFinishLaunching(_ notification: Notification) {
        window.makeKeyAndOrderFront(nil)
        window.title = "Ada Editor"
        let view = MetalView()
        view.frame.size = window.frame.size
        window.contentView?.addSubview(view)

        do {
            try setupVulkan(for: view)
        } catch {
            print(error)
        }
    }
    
    private func setupVulkan(for view: MetalView) throws {
        let extensions = try self.provideExtensions()
        
        let info = InstanceCreateInfo(
            enabledLayerNames: ["VK_LAYER_KHRONOS_validation"],
            enabledExtensionNames: extensions.map(\.extensionName)
        )

        let vulkan = try Vulkan(info: info)
        self.vulkan = vulkan
        
        let surface = try Surface(vulkan: vulkan, view: view)
        print(surface.rawPointer)
    }
    
    func provideExtensions() throws -> [ExtensionProperties] {
        let extensions = try Vulkan.getExtensions()
        
        var availableExtenstions = [ExtensionProperties]()
        var isSurfaceFound = false
        var isPlatformExtFound = false
        
        for ext in extensions {
            if ext.extensionName == VK_KHR_SURFACE_EXTENSION_NAME {
                isSurfaceFound = true
                availableExtenstions.append(ext)
            }
            
            if ext.extensionName == "VK_MVK_macos_surface" {
                availableExtenstions.append(ext)
                isPlatformExtFound = true
            }
            
            if ext.extensionName == VK_KHR_GET_PHYSICAL_DEVICE_PROPERTIES_2_EXTENSION_NAME {
                availableExtenstions.append(ext)
            }
            
            if ext.extensionName == VK_EXT_DEBUG_UTILS_EXTENSION_NAME {
                availableExtenstions.append(ext)
            }
        }
        
        assert(isSurfaceFound, "No surface extension found, is a driver installed?")
        assert(isPlatformExtFound, "No surface extension found, is a driver installed?")
        
        return availableExtenstions
    }
}

let delegate = AppDelegate()
app.delegate = delegate
app.run()

#endif

//
//        let devices = try vulkan.physicalDevices()
//
//        let preferredGPU = devices.first(where: { $0.properties.deviceType == VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU })!
//        print(preferredGPU.getQueueFamily())
//
////        let device = Device(physicalDevice: preferredGPU, createInfo: <#T##VkDeviceCreateInfo#>)
        
