//
//  VulkanRenderBackend.swift
//  
//
//  Created by v.prusakov on 8/20/23.
//

#if VULKAN

import Foundation
import Vulkan
import CVulkan
import Math

final class VulkanRenderBackend: RenderBackend {
    
    private let context: Context
    
    init(appName: String) {
        self.context = Context(appName: appName)
    }
    
    var currentFrameIndex: Int = 0
    
    func createWindow(_ windowId: Window.ID, for surface: RenderSurface, size: Size) throws {
        try self.context.createRenderWindow(with: windowId, surface: surface, size: size)
    }
    
    func resizeWindow(_ windowId: Window.ID, newSize: Size) throws {
        self.context.updateSizeForRenderWindow(windowId, size: newSize)
    }
    
    func destroyWindow(_ windowId: Window.ID) throws {
        try self.context.destroyWindow(at: windowId)
    }
    
    func beginFrame() throws {
        
    }
    
    func endFrame() throws {
        
    }

    func getImage(from texture: Texture) -> Image? {
        return nil
    }

    func makeIndexBuffer(format: IndexBufferFormat, bytes: UnsafeRawPointer, length: Int) -> IndexBuffer {
        fatalError("Kek")
    }

    func makeBuffer(length: Int, options: ResourceOptions) -> Buffer {
        fatalError("Kek")
    }
    
    func createBuffer(bytes: UnsafeRawPointer, length: Int, options: ResourceOptions) -> Buffer {
        fatalError("Kek")
    }
    
    func createIndexBuffer(index: Int, format: IndexBufferFormat, bytes: UnsafeRawPointer, length: Int) -> IndexBuffer {
        fatalError("Kek")
    }
    
    func createVertexBuffer(length: Int, binding: Int) -> VertexBuffer {
        fatalError("Kek")
    }
    
    func compileShader(from shader: Shader) throws -> CompiledShader {
        fatalError("Kek")
    }
    
    func createFramebuffer(from descriptor: FramebufferDescriptor) -> Framebuffer {
        fatalError("Kek")
    }
    
    func createRenderPipeline(from descriptor: RenderPipelineDescriptor) -> RenderPipeline {
        fatalError("Kek")
    }
    
    func makeSampler(from descriptor: SamplerDescriptor) -> Sampler {
        fatalError("Kek")
    }
    
    func makeUniformBuffer(length: Int, binding: Int) -> UniformBuffer {
        fatalError("Kek")
    }
    
    func makeUniformBufferSet() -> UniformBufferSet {
        fatalError("Kek")
    }
    
    func makeTexture(from descriptor: TextureDescriptor) -> GPUTexture {
        var imageInfo = VkImageCreateInfo(
            sType: VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO,
            pNext: nil,
            flags: 0,
            imageType: VK_IMAGE_TYPE_2D,
            format: descriptor.pixelFormat.toVulkan,
            extent: VkExtent3D(width: UInt32(descriptor.width), height: UInt32(descriptor.height), depth: 1),
            mipLevels: UInt32(descriptor.mipmapLevel),
            arrayLayers: 1,
            samples: VK_SAMPLE_COUNT_1_BIT,
            tiling: VK_IMAGE_TILING_OPTIMAL,
            usage: VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT.rawValue,
            sharingMode: VK_SHARING_MODE_EXCLUSIVE,
            queueFamilyIndexCount: 0,
            pQueueFamilyIndices: nil,
            initialLayout: VK_IMAGE_LAYOUT_UNDEFINED
        )

        if descriptor.textureType == .textureCube {
            imageInfo.flags |= VK_IMAGE_CREATE_CUBE_COMPATIBLE_BIT.rawValue
        }


        do {
            let vkImage = try Vulkan.Image(
                device: context.device,
                createInfo: imageInfo
            )

            let imageViewInfo = VkImageViewCreateInfo(
                sType: VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
                pNext: nil,
                flags: 0,
                image: vkImage.rawPointer,
                viewType: descriptor.textureType.toVulkan,
                format: descriptor.pixelFormat.toVulkan,
                components: VkComponentMapping(
                    r: VK_COMPONENT_SWIZZLE_IDENTITY,
                    g: VK_COMPONENT_SWIZZLE_IDENTITY,
                    b: VK_COMPONENT_SWIZZLE_IDENTITY,
                    a: VK_COMPONENT_SWIZZLE_IDENTITY
                ),
                subresourceRange: VkImageSubresourceRange(
                    aspectMask: VK_IMAGE_ASPECT_COLOR_BIT.rawValue,
                    baseMipLevel: 0,
                    levelCount: imageInfo.mipLevels,
                    baseArrayLayer: 0,
                    layerCount: imageInfo.arrayLayers
                )
            )

            let index = try DeviceMemory.findMemoryTypeIndex(
                for: vkImage.memoryRequirements,
                properties: properties,
                in: self.context.physicalDevices
            )

            let imageView = try Vulkan.ImageView(device: context.physicalDevice, info: imageViewInfo)
            return VulkanGPUTexture(image: vkImage, imageView: imageView)
        } catch {
            fatalError("[VulkanRenderBackend] Failed to create texture: \(error.localizedDescription)")
        }
    }
    
    func getImage(for texture2D: RID) -> Image? {
        fatalError("Kek")
    }
    
    func beginDraw(for window: Window.ID, clearColor: Color) -> DrawList {
        fatalError("Kek")
    }
    
    func beginDraw(to framebuffer: Framebuffer, clearColors: [Color]?) -> DrawList {
        fatalError("Kek")
    }
    
    func draw(_ list: DrawList, indexCount: Int, indexBufferOffset: Int, instanceCount: Int) {
        
    }

    func endDrawList(_ drawList: DrawList) {
        
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

#endif
