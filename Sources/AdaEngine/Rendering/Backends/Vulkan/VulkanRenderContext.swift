//
//  VulkanRenderContext.swift
//  AdaEngine
//
//  Created by v.prusakov on 8/20/23.
//

#if VULKAN
import Foundation
import Vulkan
import CVulkan

extension VulkanRenderBackend {
    
    final class Context {
        
        private(set) var windows: [Window.ID: RenderWindow] = [:]
        private(set) var instance: VulkanInstance
        
        init(appName: String) {
            let appInfo = VkApplicationInfo(
                sType: VK_STRUCTURE_TYPE_APPLICATION_INFO,
                pNext: nil,
                pApplicationName: appName,
                applicationVersion: Engine.shared.engineVersion.toVulkanVersion,
                pEngineName: "AdaEngine",
                engineVersion: 1,
                apiVersion: Version(string: "1.14.0").toVulkanVersion
            )
            
            let createInfo = InstanceCreateInfo(
                applicationInfo: appInfo,
                enabledLayerNames: [],
                enabledExtensionNames: []
            )
            
            self.instance = try! VulkanInstance(info: createInfo)
        }
        
        func createRenderWindow(with id: Window.ID, view: RenderView, size: Size) throws {
            if self.windows[id] != nil {
                throw ContextError.creationWindowAlreadyExists
            }
            
            let surface = try Surface(vulkan: self.instance, view: view)
            let window = RenderWindow(window: id, surface: surface)
            
            self.windows[id] = window
        }
        
        func updateSizeForRenderWindow(_ windowId: Window.ID, size: Size) {
            guard let window = self.windows[windowId] else {
                assertionFailure("Not found window by id \(windowId)")
                return
            }
            
        }
        
        func destroyWindow(at windowId: Window.ID) throws {
            if self.windows[windowId] != nil {
                assertionFailure("Window was already destroyed")
            }
            
            self.windows[windowId] = nil
        }
    }
    
    struct RenderWindow {
        let window: Window.ID
        let surface: Surface
    }
    
    enum ContextError: LocalizedError {
        case creationWindowAlreadyExists
        case commandQueueCreationFailed
        
        var errorDescription: String? {
            switch self {
            case .creationWindowAlreadyExists:
                return "RenderWindow Creation Failed: Window by given id already exists."
            case .commandQueueCreationFailed:
                return "RenderWindow Creation Failed: MTLDevice cannot create MTLCommandQueue."
            }
        }
    }
}
#endif
