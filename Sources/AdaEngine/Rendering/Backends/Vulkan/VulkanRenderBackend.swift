//
//  VulkanRenderBackend.swift
//  
//
//  Created by v.prusakov on 8/20/23.
//

#if VULKAN
import Foundation
import CVulkan
import Vulkan
import Math

final class VulkanRenderBackend: RenderBackend {
    private(set) var renderDevice: any RenderDevice
    
    let context: Context

    var currentFrameIndex: Int = 0
    private var inFlightSemaphore: DispatchSemaphore

    init(appName: String) {
        #if canImport(Volk)
        try! Volk.load()
        #endif
        
        self.context = Context(appName: appName)

        self.inFlightSemaphore = DispatchSemaphore(value: RenderEngine.configurations.maxFramesInFlight)
        
        self.renderDevice = VulkanRenderDevice(context: context)
    }
    
    func createLocalRenderDevice() -> any RenderDevice {
        VulkanRenderDevice(context: context)
    }
    
    func createWindow(_ windowId: UIWindow.ID, for surface: any RenderSurface, size: Math.SizeInt) throws {
        try self.context.createRenderWindow(with: windowId, view: surface, size: size)
    }
    
    func resizeWindow(_ windowId: UIWindow.ID, newSize: Math.SizeInt) throws {
        self.context.updateSizeForRenderWindow(windowId, size: newSize)
    }
    
    func destroyWindow(_ windowId: UIWindow.ID) throws {
        try self.context.destroyWindow(at: windowId)
    }
    
    func beginFrame() throws {
        
        let fence = self.context.drawFences[self.currentFrameIndex]
        try fence.wait()
        
        let cmdBuffer = self.context.commandBuffers[self.currentFrameIndex]
        try cmdBuffer.beginUpdate()
    }
    
    func endFrame() throws {
        self.inFlightSemaphore.wait()
        
        let cmdBuffer = self.context.commandBuffers[self.currentFrameIndex]
        
        try cmdBuffer.endUpdate()
        
        self.inFlightSemaphore.signal()
        
        currentFrameIndex = (currentFrameIndex + 1) % RenderEngine.configurations.maxFramesInFlight
    }
}

extension Version {
    var toVulkanVersion: UInt32 {
        return vkMakeApiVersion(UInt32(self.major), UInt32(self.minor), UInt32(self.patch))
    }
}

extension PixelFormat {
    var toVulkan: VkFormat {
        switch self {
        case .bgra8:
            return VK_FORMAT_B8G8R8A8_UINT
        case .bgra8_srgb:
            return VK_FORMAT_B8G8R8A8_SRGB
        case .rgba8:
            return VK_FORMAT_R8G8B8A8_UINT
        case .rgba_16f:
            return VK_FORMAT_R16G16B16A16_SFLOAT
        case .rgba_32f:
            return VK_FORMAT_R32G32B32A32_SFLOAT
        case .depth_32f_stencil8:
            return VK_FORMAT_D32_SFLOAT_S8_UINT
        case .depth_32f:
            return VK_FORMAT_D32_SFLOAT
        case .depth24_stencil8:
            return VK_FORMAT_D24_UNORM_S8_UINT
        case .none:
            return VK_FORMAT_UNDEFINED
        }
    }
}

extension Texture.TextureType {
    var toVulkan: VkImageViewType {
        switch self {
        case .texture1D:
            return VK_IMAGE_VIEW_TYPE_1D
        case .texture1DArray:
            return VK_IMAGE_VIEW_TYPE_1D_ARRAY
        case .texture2D:
            return VK_IMAGE_VIEW_TYPE_2D
        case .texture2DArray:
            return VK_IMAGE_VIEW_TYPE_2D_ARRAY
        case .texture2DMultisample:
            return VK_IMAGE_VIEW_TYPE_2D
        case .texture2DMultisampleArray:
            return VK_IMAGE_VIEW_TYPE_2D_ARRAY
        case .textureCube:
            return VK_IMAGE_VIEW_TYPE_CUBE
        case .texture3D:
            return VK_IMAGE_VIEW_TYPE_3D
        case .textureBuffer:
            fatalError("Unsupported type")
        }
    }
}

class VulkanRenderCommandBuffer: DrawCommandBuffer {
    let framebuffer: VulkanFramebuffer
    
    init(framebuffer: VulkanFramebuffer) {
        self.framebuffer = framebuffer
    }
}

#endif
