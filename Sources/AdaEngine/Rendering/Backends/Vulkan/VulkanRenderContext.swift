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
import Math

#if canImport(WinSDK)
import WinSDK
#endif

#if canImport(X11)
import X11
#endif

#if canImport(Wayland)
import Wayland
#endif

#if canImport(MetalKit)
import MetalKit
#endif

extension VulkanRenderBackend {
    
    struct VKSwapchain {
        let format: VkFormat
        let colorSpace: VkColorSpaceKHR
        let surface: Surface
        let renderPass: Vulkan.RenderPass
        
        var vkSwapchain: Vulkan.Swapchain?
        
        var images: [VkImage] = []
        var imageViews: [Vulkan.ImageView] = []
        var framebuffers: [Vulkan.Framebuffer] = []
    }
    
    struct RenderWindow {
        var swapchain: VKSwapchain
    }

    final class Context {

        private(set) var windows: [UIWindow.ID: RenderWindow] = [:]
        private(set) var instance: VulkanInstance
        private(set) var physicalDevice: PhysicalDevice
        private(set) var logicalDevice: Device

        private(set) var physicalDevices: [PhysicalDevice]
        private(set) var deviceQueueFamilyProperties: [[QueueFamilyProperties]]
        
        private(set) var commandPool: CommandPool
        private(set) var commandBuffers: [Vulkan.CommandBuffer] = []
        private(set) var drawFences: [Vulkan.Fence] = []

        init(appName: String) {
            let version = Self.determineVulkanVersion()
            let engineName = "AdaEngine"
            
            let holder = VulkanUtils.TemporaryBufferHolder(label: "Vulkan Render Context")

            do {
                let appInfo = VkApplicationInfo(
                    sType: VK_STRUCTURE_TYPE_APPLICATION_INFO,
                    pNext: nil,
                    pApplicationName: holder.unsafePointerCopy(string: appName),
                    applicationVersion: Version(string: "1.0.0").toVulkanVersion,
                    pEngineName: holder.unsafePointerCopy(string: engineName),
                    engineVersion: Engine.shared.engineVersion.toVulkanVersion,
                    apiVersion: version
                )
                
                let extensions = try Self.getAvailableExtensionNames()
                let layers = try VulkanInstance.getLayerProperties()

                let createInfo = InstanceCreateInfo(
                    applicationInfo: holder.unsafePointerCopy(from: appInfo),
                    enabledLayerNames: layers.map { $0.layerName },
                    enabledExtensionNames: extensions,
                    flags: VK_INSTANCE_CREATE_ENUMERATE_PORTABILITY_BIT_KHR.rawValue
                )

                let vulkanInstance = try VulkanInstance(info: createInfo)
                
                #if canImport(Volk)
                Volk.loadInstance(vulkanInstance.pointer)
                #endif

                self.instance = vulkanInstance
                self.physicalDevices = try self.instance.physicalDevices()
                self.deviceQueueFamilyProperties = self.physicalDevices.map { $0.getQueueFamily() }
                let deviceIndex = try Self.getPreferredPhysicalDeviceIndex(in: self.physicalDevices)
                
                self.physicalDevice = self.physicalDevices[deviceIndex]
                self.logicalDevice = try Self.createLogicalDevice(
                    for: self.physicalDevices,
                    deviceIndex: deviceIndex,
                    deviceQueueFamilyProperties: self.deviceQueueFamilyProperties
                )
                
                let queue = self.deviceQueueFamilyProperties[deviceIndex].first(where: { $0.queueFlags.contains(.graphicsBit) })!
                
                self.commandPool = try CommandPool(device: self.logicalDevice, queueFamilyIndex: queue.index)
                
                for _ in 0 ..< RenderEngine.configurations.maxFramesInFlight {
                    let cmdBuffer = try Vulkan.CommandBuffer(
                        device: self.logicalDevice,
                        commandPool: self.commandPool,
                        isPrimary: true
                    )
                    
                    self.commandBuffers.append(cmdBuffer)
                    
                    let fence = try Vulkan.Fence(device: self.logicalDevice)
                    self.drawFences.append(fence)
                }
            } catch {
                fatalError("[VulkanRenderBackend] \(error.localizedDescription)")
            }
        }

        private static func createLogicalDevice(
            for physicalDevices: [PhysicalDevice],
            deviceIndex: Int,
            deviceQueueFamilyProperties: [[QueueFamilyProperties]]
        ) throws -> Device {
            let gpu = physicalDevices[deviceIndex]
            let queueFamiliesProps = deviceQueueFamilyProperties[deviceIndex]

            let deviceExtensions = try gpu.getExtensions()
            var availableExtenstions = [String]()

            let optionalExtensions: Set<String> = [
                VK_KHR_MULTIVIEW_EXTENSION_NAME,
                VK_KHR_FRAGMENT_SHADING_RATE_EXTENSION_NAME,
                VK_KHR_CREATE_RENDERPASS_2_EXTENSION_NAME,
                VK_KHR_SHADER_FLOAT16_INT8_EXTENSION_NAME,
                VK_KHR_STORAGE_BUFFER_STORAGE_CLASS_EXTENSION_NAME,
                VK_KHR_16BIT_STORAGE_EXTENSION_NAME,
                VK_KHR_IMAGE_FORMAT_LIST_EXTENSION_NAME,
                VK_KHR_MAINTENANCE_2_EXTENSION_NAME,
                VK_EXT_PIPELINE_CREATION_CACHE_CONTROL_EXTENSION_NAME,
                VK_EXT_SUBGROUP_SIZE_CONTROL_EXTENSION_NAME
            ]
            
            availableExtenstions.append(VK_KHR_SWAPCHAIN_EXTENSION_NAME)

            for ext in deviceExtensions {
                if optionalExtensions.contains(ext.extensionName) {
                    availableExtenstions.append(ext.extensionName)
                }
            }

            let properties: [Float] = [0.0]
            var queueCreateInfos = [DeviceQueueCreateInfo]()

            for (index, prop) in queueFamiliesProps.enumerated() where prop.queueFlags.isSubset(of: [.graphicsBit, .computeBit, .transferBit]) {
                queueCreateInfos.append(
                    DeviceQueueCreateInfo(
                        queueFamilyIndex: UInt32(index),
                        flags: .none,
                        queuePriorities: properties
                    )
                )
            }

            var features = gpu.features
            features.robustBufferAccess = false

            let info = DeviceCreateInfo(
                enabledExtensions: availableExtenstions,
                layers: [],
                queueCreateInfo: queueCreateInfos,
                enabledFeatures: features
            )

            return try Device(physicalDevice: gpu, createInfo: info)
        }

        private func deviceSupportPresent(deviceIndex: Int, surface: Surface) -> Bool {
            let device = self.physicalDevices[deviceIndex]
            let queueFamiliesProps = self.deviceQueueFamilyProperties[deviceIndex]

            for prop in queueFamiliesProps {
                do {
                if try prop.queueFlags.contains(.graphicsBit) && device.supportSurface(surface, queueFamily: prop) {
                        return true
                    }
                } catch {
                    continue
                }
            }

            return false
        }

        // FIXME: Make it better
        private static func getPreferredPhysicalDeviceIndex(in devices: [PhysicalDevice]) throws -> Int {
            if devices.isEmpty {
                throw ContextError.initializationFailure("Could not find any compitable devices for Vulkan. Do you have a compitable Vulkan devices?")
            }

            let preferredGPU = devices.firstIndex(where: { $0.properties.deviceType == VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU })

            return preferredGPU ?? 0
        }

        private static func determineVulkanVersion() -> UInt32 {
            var version: UInt32 = UInt32.max
            let result = vkEnumerateInstanceVersion(&version)

            if result != VK_SUCCESS {
                return vkApiVersion_1_0()
            }

            return version
        }

        private static func getAvailableExtensionNames() throws -> [String] {
            let extensions = try VulkanInstance.getExtensions()

            var availableExtenstions = [String]()
            var isPlatformExtFound = false
            var isSurfaceExtFound = false

            let optionalExtensions: Set<String> = [
                VK_KHR_PORTABILITY_ENUMERATION_EXTENSION_NAME,
                VK_KHR_GET_PHYSICAL_DEVICE_PROPERTIES_2_EXTENSION_NAME,
            ]

            for ext in extensions {
                if optionalExtensions.contains(ext.extensionName) {
                    availableExtenstions.append(ext.extensionName)
                }
                
                if ext.extensionName == VK_KHR_SURFACE_EXTENSION_NAME {
                    availableExtenstions.append(ext.extensionName)
                    isSurfaceExtFound = true
                }

                if ext.extensionName == Self.platformSpecificSurfaceExtensionName {
                    availableExtenstions.append(ext.extensionName)
                    isPlatformExtFound = true
                }

                #if DEBUG
                if ext.extensionName == VK_EXT_DEBUG_UTILS_EXTENSION_NAME {
                    availableExtenstions.append(ext.extensionName)
                }
                #endif

                if ext.extensionName == VK_EXT_DEBUG_REPORT_EXTENSION_NAME && Engine.shared.useValidationLayers {
                    availableExtenstions.append(ext.extensionName)
                }
            }

            if !isPlatformExtFound {
                availableExtenstions.append(self.platformSpecificSurfaceExtensionName)
            }

            if !isSurfaceExtFound {
                availableExtenstions.append(VK_KHR_SURFACE_EXTENSION_NAME)
            }

            return availableExtenstions
        }

        // TODO: Change to constants
        // TODO: Headless mode
        private static var platformSpecificSurfaceExtensionName: String {
#if MACOS || IOS || TVOS || VISIONOS
            return "VK_EXT_METAL_SURFACE_EXTENSION_NAME"//VK_EXT_METAL_SURFACE_EXTENSION_NAME
#elseif WINDOWS
            return "VK_KHR_win32_surface"
#elseif LINUX
            return "VK_KHR_xlib_surface"
#elseif ANDROID
            return "VK_KHR_xlib_surface"
#else
            return "NotFound"
#endif
        }

        @MainActor
        func createRenderWindow(with id: UIWindow.ID, view: RenderSurface, size: Math.SizeInt) throws {
            if self.windows[id] != nil {
                throw ContextError.creationWindowAlreadyExists
            }
            
            let holder = VulkanUtils.TemporaryBufferHolder(label: "Create Vulkan Window")
            let surface = try Surface.createSurface(vulkan: self.instance, view: view)
            let formats = try self.physicalDevice.surfaceFormats(for: surface)
            
            var format: VkFormat = VK_FORMAT_UNDEFINED
            var colorSpace: VkColorSpaceKHR = VK_COLOR_SPACE_SRGB_NONLINEAR_KHR
            
            if formats.count == 1 && formats[0].format == VK_FORMAT_UNDEFINED {
                format = VK_FORMAT_B8G8R8A8_UNORM;
                colorSpace = formats[0].colorSpace;
            } else {
                let preferredFormats = VK_FORMAT_B8G8R8A8_UNORM
                let lessPreferredFormat = VK_FORMAT_R8G8B8A8_UNORM
                
                for item in formats where item.format == preferredFormats || item.format == lessPreferredFormat {
                    format = item.format
                    
                    if item.format == preferredFormats {
                        break
                    }
                }
            }
            
            var attachment = VkAttachmentDescription()
            attachment.format = format
            attachment.samples = VK_SAMPLE_COUNT_1_BIT
            attachment.loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR
            attachment.storeOp = VK_ATTACHMENT_STORE_OP_STORE
            attachment.stencilLoadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE
            attachment.stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE
            attachment.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED
            attachment.finalLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR
            
            var colorReference = VkAttachmentReference()
            colorReference.layout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL
            
            let pColorAttachments = holder.unsafePointerCopy(from: colorReference)
            
            var subpass = VkSubpassDescription()
            subpass.pipelineBindPoint = VK_PIPELINE_BIND_POINT_GRAPHICS
            subpass.colorAttachmentCount = 1
            subpass.pColorAttachments = pColorAttachments
            
            let pAttachments = holder.unsafePointerCopy(from: attachment)
            let pSubpasses = holder.unsafePointerCopy(from: subpass)

            var passInfo = VkRenderPassCreateInfo()
            passInfo.sType = VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO
            passInfo.attachmentCount = 1
            passInfo.pAttachments = pAttachments
            passInfo.subpassCount = 1
            passInfo.pSubpasses = pSubpasses
            
            let renderPass = try Vulkan.RenderPass(device: self.logicalDevice, createInfo: passInfo)
            
            let swapchain = VKSwapchain(
                format: format,
                colorSpace: colorSpace,
                surface: surface,
                renderPass: renderPass
            )
            let window = RenderWindow(swapchain: swapchain)

            self.windows[id] = window
            
            self.updateSizeForRenderWindow(id, size: size)
        }

        func updateSizeForRenderWindow(_ windowId: UIWindow.ID, size: Math.SizeInt) {
            guard var window = self.windows[windowId] else {
                assertionFailure("Not found window by id \(windowId)")
                return
            }
            
            let holder = VulkanUtils.TemporaryBufferHolder(label: "Resize Render Window")
            
            do {
                let surface = window.swapchain.surface
                let capabilities = try self.physicalDevice.surfaceCapabilities(for: surface)
                
                var extent = VkExtent2D()
                // The extent isn't defined
                if capabilities.currentExtent.width == 0xFFFFFFFF {
                    extent.width = Math.clamp(UInt32(size.width), capabilities.minImageExtent.width, capabilities.maxImageExtent.width)
                    extent.height = Math.clamp(UInt32(size.height), capabilities.minImageExtent.height, capabilities.maxImageExtent.height)
                }
                
                var createInfo = VkSwapchainCreateInfoKHR()
            createInfo.sType = VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR
                createInfo.surface = surface.rawPointer
                createInfo.minImageCount = 1
                createInfo.imageExtent = extent
                createInfo.imageFormat = window.swapchain.format
                createInfo.imageColorSpace = window.swapchain.colorSpace
                createInfo.imageArrayLayers = 1
                createInfo.imageUsage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT.rawValue
                createInfo.imageSharingMode = VK_SHARING_MODE_EXCLUSIVE
//                createInfo.preTransform = surface_transform_bits;
//                createInfo.compositeAlpha = composite_alpha;
//                createInfo.presentMode = present_mode;
                createInfo.clipped = true
                
                let swapchain = try Vulkan.Swapchain(device: logicalDevice, createInfo: createInfo)
                window.swapchain.vkSwapchain = swapchain
                
                let images = try swapchain.getImages()
                
                var imageViewCreateInfo = VkImageViewCreateInfo()
                imageViewCreateInfo.sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO
                imageViewCreateInfo.viewType = VK_IMAGE_VIEW_TYPE_2D
                imageViewCreateInfo.format = window.swapchain.format
                imageViewCreateInfo.components.r = VK_COMPONENT_SWIZZLE_R
                imageViewCreateInfo.components.g = VK_COMPONENT_SWIZZLE_G
                imageViewCreateInfo.components.b = VK_COMPONENT_SWIZZLE_B
                imageViewCreateInfo.components.a = VK_COMPONENT_SWIZZLE_A
                imageViewCreateInfo.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT.rawValue
                imageViewCreateInfo.subresourceRange.levelCount = 1
                imageViewCreateInfo.subresourceRange.layerCount = 1
                
                let imageViews = try images.map {
                    imageViewCreateInfo.image = $0
                    return try Vulkan.ImageView(device: logicalDevice, info: imageViewCreateInfo)
                }
                
                window.swapchain.images = images
                window.swapchain.imageViews = imageViews
                
                var framebufferCreateInfo = VkFramebufferCreateInfo()
                framebufferCreateInfo.sType = VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO
                framebufferCreateInfo.renderPass = window.swapchain.renderPass.rawPointer
                framebufferCreateInfo.width = extent.width
                framebufferCreateInfo.height = extent.height
                framebufferCreateInfo.layers = 1
                framebufferCreateInfo.attachmentCount = 1
                
                let framebuffers = try imageViews.map {
                    framebufferCreateInfo.pAttachments = holder.unsafePointerCopy(from: $0.rawPointer)
                    return try Vulkan.Framebuffer(device: logicalDevice, createInfo: framebufferCreateInfo)
                }
                
                window.swapchain.framebuffers = framebuffers
                
                self.windows[windowId] = window
            } catch {
                assertionFailure("Can't resize window with error \(error)")
            }
            
        }

        func destroyWindow(at windowId: UIWindow.ID) throws {
            if self.windows[windowId] != nil {
                assertionFailure("Window was already destroyed")
            }

            self.windows[windowId] = nil
            
            // Destroy swapchain, surface
        }
    }
    
    private struct QueueFamilyIndices {
        let graphicsIndex: Int
        let presentationIndex: Int
        let isSeparate: Bool
    }

    enum ContextError: LocalizedError {
        case creationWindowAlreadyExists
        case commandQueueCreationFailed
        case initializationFailure(String)

        var errorDescription: String? {
            switch self {
            case .creationWindowAlreadyExists:
                return "[VulkanContext] RenderWindow Creation Failed: Window by given id already exists."
            case .commandQueueCreationFailed:
                return "[VulkanContext] RenderWindow Creation Failed: MTLDevice cannot create MTLCommandQueue."
            case .initializationFailure(let message):
                return "[VulkanContext] \(message)"
            }
        }
    }
}

private extension Surface {
    @MainActor
    static func createSurface(vulkan: VulkanInstance, view: RenderSurface) throws -> Surface {
        #if canImport(MetalKit)
        guard let layer = (view as? MTKView)?.layer as? CAMetalLayer else {
            throw VKError(code: VK_ERROR_INITIALIZATION_FAILED, message: "Can't cast layer to CAMetalLayer")
        }
        
        var createInfo = VkMacOSSurfaceCreateInfoMVK()
        createInfo.sType = VK_STRUCTURE_TYPE_METAL_SURFACE_CREATE_INFO_EXT;
        createInfo.pView = UnsafeRawPointer(Unmanaged.passUnretained(layer).toOpaque())
        
        var surface: VkSurfaceKHR?
        let result = withUnsafePointer(to: &createInfo) { ptr in
            vkCreateMacOSSurfaceMVK(vulkan.pointer, ptr, nil, &surface)
        }
        
        guard let surface = surface, result == VK_SUCCESS else {
            throw VKError(code: result, message: "Can't create macOS surface")
        }
        
        return Surface(vulkan: vulkan, surface: surface)
        #elseif os(Linux)
        return try makeSurfaceLinux(vulkan: vulkan, view: view)
        #elseif os(Windows)
        var createInfo = VkWin32SurfaceCreateInfoKHR()
        createInfo.sType = VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR
        createInfo.hinstance = display
        createInfo.hwnd = window

        var surface: VkSurfaceKHR?
        let result = withUnsafePointer(to: &createInfo) { ptr in
            vkCreateWin32SurfaceKHR(vulkan.pointer, ptr, nil, &surface)
        }
        
        guard let surface = surface, result == VK_SUCCESS else {
            throw VKError(code: result, message: "Can't create Windows surface")
        }

        return Surface(vulkan: vulkan, surface: surface)
        #elseif os(Android)
        var createInfo = VkAndroidSurfaceCreateInfoKHR()
        createInfo.sType = VK_STRUCTURE_TYPE_ANDROID_SURFACE_CREATE_INFO_KHR
        // createInfo.window = window

        var surface: VkSurfaceKHR?
        let result = withUnsafePointer(to: &createInfo) { ptr in
            vkCreateAndroidSurfaceKHR(vulkan.pointer, ptr, nil, &surface)
        }
        
        guard let surface = surface, result == VK_SUCCESS else {
            throw VKError(code: result, message: "Can't create Android surface")
        }

        return Surface(vulkan: vulkan, surface: surface)
        #else
        fatalError("No render surface selected")
        #endif
    }

    #if os(Linux)
    @MainActor
    private static func makeSurfaceLinux(vulkan: VulkanInstance, view: RenderSurface) throws -> Surface {
        #if canImport(X11)
        var createInfo = VkXlibSurfaceCreateInfoKHR()
        createInfo.sType = VK_STRUCTURE_TYPE_XLIB_SURFACE_CREATE_INFO_KHR
        createInfo.dpy = display
        createInfo.window = window
        
        var surface: VkSurfaceKHR?
        let result = withUnsafePointer(to: &createInfo) { ptr in
            vkCreateXlibSurfaceKHR(vulkan.pointer, ptr, nil, &surface)
        }
        
        guard let surface = surface, result == VK_SUCCESS else {
            throw VKError(code: result, message: "Can't create Linux X11 surface")
        }
        
        self.init(vulkan: vulkan, surface: surface)
        #elseif canImport(Wayland)
        let waylandView = view as! WaylandView

        var createInfo = VkWaylandSurfaceCreateInfoKHR()
        createInfo.sType = VK_STRUCTURE_TYPE_WAYLAND_SURFACE_CREATE_INFO_KHR
        createInfo.surface = waylandView.surface
        createInfo.display = waylandView.windowManager?.display
        
        var surface: VkSurfaceKHR?
        let result = withUnsafePointer(to: &createInfo) { ptr in
            vkCreateWaylandSurfaceKHR(vulkan.pointer, ptr, nil, &surface)
        }
        
        guard let surface = surface, result == VK_SUCCESS else {
            throw VKError(code: result, message: "Can't create Linux Wayland surface")
        }
        
        return Surface(vulkan: vulkan, surface: surface)
        #else
        #error("Not supported surface")
        fatalError("Not supported surface")
        #endif
    }
    #endif
}

#endif
