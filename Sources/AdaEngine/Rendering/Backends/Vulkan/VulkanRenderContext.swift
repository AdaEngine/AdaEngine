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
        private(set) var physicalDevice: PhysicalDevice
        private(set) var logicalDevice: Device

        private(set) var physicalDevices: [PhysicalDevice]
        private(set) var deviceQueueFamilyProperties: [[QueueFamilyProperties]]

        init(appName: String) {
            let version = Self.determineVulkanVersion()
            let engineName = "AdaEngine"

            do {
                let vulkanInstance = try appName.withCString { appNamePtr in
                    return try engineName.withCString { engineNamePtr in
                        var appInfo = VkApplicationInfo(
                            sType: VK_STRUCTURE_TYPE_APPLICATION_INFO,
                            pNext: nil,
                            pApplicationName: appNamePtr,
                            applicationVersion: Version(string: "1.0.0").toVulkanVersion,
                            pEngineName: engineNamePtr,
                            engineVersion: Engine.shared.engineVersion.toVulkanVersion,
                            apiVersion: version
                        )

                        let extensions = try Self.getAvailableExtensionNames()
                        let layers = try VulkanInstance.getLayerProperties()

                        let createInfo = InstanceCreateInfo(
                            applicationInfo: &appInfo,
                            enabledLayerNames: layers.map { $0.layerName },
                            enabledExtensionNames: extensions,
                            flags: VK_INSTANCE_CREATE_ENUMERATE_PORTABILITY_BIT_KHR.rawValue
                        )

                        return try VulkanInstance(info: createInfo)
                    }
                }

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
            return VK_EXT_METAL_SURFACE_EXTENSION_NAME
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
#endif
