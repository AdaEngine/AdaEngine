//
//  File.swift
//  
//
//  Created by v.prusakov on 8/15/21.
//

import Vulkan
@_implementationOnly import CVulkan
import Math

public let NotFound = Int.max

struct QueueFamilyIndices {
    let graphicsIndex: Int
    let presentationIndex: Int
    let isSeparate: Bool
}

public class RenderContext {
    
    public private(set) var vulkan: Vulkan?
    private var queueFamilyIndicies: QueueFamilyIndices!
    private var device: Device!
    private var surface: Surface!
    private var gpu: PhysicalDevice!
    
    private var graphicsQueue: VkQueue?
    private var presentationQueue: VkQueue?
    
    public let vulkanVersion: UInt32
    
    public required init() {
        self.vulkanVersion = Self.determineVulkanVersion()
    }
    
    public func initialize(with appName: String) throws {
        let vulkan = try self.createInstance(appName: appName)
        self.vulkan = vulkan
        
        let gpu = try self.createGPU(vulkan: vulkan)
        self.gpu = gpu
    }
    
    // MARK: - Private
    
    private func createInstance(appName: String) throws -> Vulkan {
        let extensions = try Self.provideExtensions()
        
        let appInfo = VkApplicationInfo(
            sType: VK_STRUCTURE_TYPE_APPLICATION_INFO,
            pNext: nil,
            pApplicationName: appName,
            applicationVersion: 0,
            pEngineName: "Ada Engine",
            engineVersion: 0,
            apiVersion: vulkanVersion
        )
        
        let info = InstanceCreateInfo(
//            applicationInfo: appInfo,
            // TODO: Add enabledLayers flag to manage layers
            enabledLayerNames: ["VK_LAYER_KHRONOS_validation"],
            enabledExtensionNames: extensions.map(\.extensionName)
        )
        
        return try Vulkan(info: info)
    }
    
    private func createWindow(surface: Surface, size: Vector2) throws {
        if self.graphicsQueue == nil && self.presentationQueue == nil {
            try self.createQueues(gpu: self.gpu, surface: surface)
        }
    }
    
    private func createGPU(vulkan: Vulkan) throws -> PhysicalDevice {
        let devices = try vulkan.physicalDevices()
        
        if devices.isEmpty {
            throw AdaError("Could not find any compitable devices for Vulkan. Do you have a compitable Vulkan devices?")
        }
        
        let preferredGPU =
            devices.first(where: { $0.properties.deviceType == VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU }) ?? devices[0]
        
        return preferredGPU
    }
    
    private func createQueues(gpu: PhysicalDevice, surface: Surface) throws {
        let queues = gpu.getQueueFamily()
        
        if queues.isEmpty {
            throw AdaError("Could not find any queues for selected GPU.")
        }
        
        let supporterPresentationQueues = try queues.map { try gpu.supportSurface(surface, queueFamily: $0) }
        
        var presentationQueueIndex = NotFound
        var graphicsQueueIndex = NotFound
        
        for (index, queue) in queues.enumerated() {
            if queue.queueFlags.contains(.graphicsBit) && graphicsQueueIndex == NotFound {
                graphicsQueueIndex = index
            }
            
            if supporterPresentationQueues[index] == true {
                graphicsQueueIndex = index
                presentationQueueIndex = index
                break
            }
        }
        
        // We dont find presentation queue
        if
            presentationQueueIndex == NotFound,
            let index = supporterPresentationQueues.firstIndex(where: { $0 == true })
        {
            presentationQueueIndex = index
        }
        
        assert(presentationQueueIndex != NotFound || graphicsQueueIndex != NotFound, "Presentation and/or graphics queues not found")
        
        let indecies = QueueFamilyIndices(
            graphicsIndex: graphicsQueueIndex,
            presentationIndex: presentationQueueIndex,
            isSeparate: graphicsQueueIndex != presentationQueueIndex
        )
        
        self.queueFamilyIndicies = indecies
        
        let device = try self.createDevice(for: gpu, surface: surface, queueIndecies: indecies)
        self.device = device
        
        self.graphicsQueue = device.getQueue(at: indecies.graphicsIndex)
        self.presentationQueue = indecies.isSeparate ? device.getQueue(at: indecies.presentationIndex) : self.graphicsQueue
    }
    
    private func createSwapchain() {
        //        let createInfo = VkSwapchainCreateInfoKHR(
        //            sType: k,
        //            pNext: nil, flags: 0,
        //            surface: surface.rawPointer,
        //            minImageCount: <#T##UInt32#>,
        //            imageFormat: <#T##VkFormat#>,
        //            imageColorSpace: <#T##VkColorSpaceKHR#>,
        //            imageExtent: <#T##VkExtent2D#>,
        //            imageArrayLayers: <#T##UInt32#>,
        //            imageUsage: <#T##VkImageUsageFlags#>,
        //            imageSharingMode: <#T##VkSharingMode#>,
        //            queueFamilyIndexCount: <#T##UInt32#>,
        //            pQueueFamilyIndices: <#T##UnsafePointer<UInt32>!#>,
        //            preTransform: <#T##VkSurfaceTransformFlagBitsKHR#>,
        //            compositeAlpha: <#T##VkCompositeAlphaFlagBitsKHR#>,
        //            presentMode: <#T##VkPresentModeKHR#>,
        //            clipped: <#T##VkBool32#>,
        //            oldSwapchain: <#T##VkSwapchainKHR!#>)
        //
        //        let swapchain = Swapchain(device: device, createInfo: <#T##VkSwapchainCreateInfoKHR#>)
    }
    
    private func createDevice(for gpu: PhysicalDevice, surface: Surface, queueIndecies: QueueFamilyIndices) throws -> Device {
        
        let deviceExtensions = try gpu.getExtensions()
        var availableExtenstions = [ExtensionProperties]()
        
        for ext in deviceExtensions {
            if ext.extensionName == VK_KHR_SWAPCHAIN_EXTENSION_NAME {
                availableExtenstions.append(ext)
            }
        }
        
        
        let properties: [Float] = [0.0]
        
        var queueCreateInfos = [DeviceQueueCreateInfo]()
        queueCreateInfos.append(
            DeviceQueueCreateInfo(
                queueFamilyIndex: UInt32(queueIndecies.graphicsIndex),
                flags: .none,
                queuePriorities: properties
            )
        )
        
        if queueIndecies.isSeparate {
            queueCreateInfos.append(
                DeviceQueueCreateInfo(
                    queueFamilyIndex: UInt32(queueIndecies.presentationIndex),
                    flags: .none,
                    queuePriorities: properties
                )
            )
        }
        
        var features = gpu.features
        features.robustBufferAccess = false
        
        let info = DeviceCreateInfo(
            enabledExtensions: availableExtenstions.map(\.extensionName),
            layers: [],
            queueCreateInfo: queueCreateInfos,
            enabledFeatures: features
        )
        
        return try Device(physicalDevice: gpu, createInfo: info)
    }
    
}

extension RenderContext {
    
    private static func determineVulkanVersion() -> UInt32 {
        var version: UInt32 = UInt32.max
        let result = vkEnumerateInstanceVersion(&version)
        
        if result != VK_SUCCESS {
            fatalError("Vulkan API got error when trying get sdk version")
        }
        
        return vkMakeApiVersion(version, version, version)
    }
    
    private static func provideExtensions() throws -> [ExtensionProperties] {
        let extensions = try Vulkan.getExtensions()
        
        var availableExtenstions = [ExtensionProperties]()
        var isSurfaceFound = false
        var isPlatformExtFound = false
        
        for ext in extensions {
            if ext.extensionName == VK_KHR_SURFACE_EXTENSION_NAME {
                isSurfaceFound = true
                availableExtenstions.append(ext)
            }
            
            /// TODO: Change it later for platform specific surface
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

#if os(macOS)

import MetalKit

public extension RenderContext {
    func createWindow(for view: MTKView, size: Vector2) throws {
        precondition(self.vulkan != nil, "Vulkan instance not created.")
        
        let surface = try Surface(vulkan: self.vulkan!, view: view)
        try self.createWindow(surface: surface, size: size)
    }
}

#endif

public struct AdaError: LocalizedError {
    let message: String
    
    public init(_ message: String) {
        self.message = message
    }
    
    public var errorDescription: String? {
        return message
    }
}
