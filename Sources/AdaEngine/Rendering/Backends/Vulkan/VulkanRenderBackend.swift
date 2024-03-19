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

    private let context: Context

    var currentFrameIndex: Int = 0
    private var inFlightSemaphore: DispatchSemaphore
    private var commandQueues: [Vulkan.CommandBuffer] = []

    init(appName: String) {
        self.context = Context(appName: appName)

        self.inFlightSemaphore = DispatchSemaphore(value: RenderEngine.configurations.maxFramesInFlight)
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
        do {
            let indexBuffer = try VulkanIndexBuffer(device: self.context.logicalDevice, size: length, queueFamilyIndecies: [], indexFormat: format)
            let rawPointer = UnsafeMutableRawPointer(mutating: bytes)
            indexBuffer.setData(rawPointer, byteCount: length)
            return indexBuffer
        } catch {
            fatalError("\(error.localizedDescription)")
        }
    }

    func makeBuffer(length: Int, options: ResourceOptions) -> Buffer {
        do {
            return try VulkanBuffer(
                device: self.context.logicalDevice,
                size: length,
                usage: VK_BUFFER_USAGE_STORAGE_BUFFER_BIT.rawValue,
                queueFamilyIndecies: []
            )
        } catch {
            fatalError("\(error.localizedDescription)")
        }
    }

    func makeBuffer(bytes: UnsafeRawPointer, length: Int, options: ResourceOptions) -> Buffer {
        do {
            let buffer = try VulkanBuffer(
                device: self.context.logicalDevice,
                size: length,
                usage: VK_BUFFER_USAGE_STORAGE_BUFFER_BIT.rawValue,
                queueFamilyIndecies: []
            )
            buffer.setData(UnsafeMutableRawPointer(mutating: bytes), byteCount: length)

            return buffer
        } catch {
            fatalError("\(error.localizedDescription)")
        }
    }

    func makeVertexBuffer(length: Int, binding: Int) -> VertexBuffer {
        do {
            return try VulkanVertexBuffer(
                device: self.context.logicalDevice,
                size: length,
                queueFamilyIndecies: [],
                binding: binding
            )
        } catch {
            fatalError("\(error.localizedDescription)")
        }
    }
    
    func compileShader(from shader: Shader) throws -> CompiledShader {
        return try VulkanShader.make(from: shader, device: self.context.logicalDevice)
    }
    
    func makeFramebuffer(from descriptor: FramebufferDescriptor) -> Framebuffer {
        return VulkanFramebuffer(device: self.context.logicalDevice, descriptor: descriptor)
    }
    
    func makeRenderPipeline(from descriptor: RenderPipelineDescriptor) -> RenderPipeline {
        do {
            return try VulkanRenderPipeline(device: self.context.logicalDevice, descriptor: descriptor)
        } catch {
            fatalError("\(error.localizedDescription)")
        }
    }
    
    func makeSampler(from descriptor: SamplerDescriptor) -> Sampler {
        do {
            return try VulkanSampler(device: self.context.logicalDevice, descriptor: descriptor)
        } catch {
            fatalError("\(error.localizedDescription)")
        }
    }
    
    func makeUniformBuffer(length: Int, binding: Int) -> UniformBuffer {
        do {
            return try VulkanUniformBuffer(device: self.context.logicalDevice, size: length, queueFamilyIndecies: [], binding: binding)
        } catch {
            fatalError("\(error.localizedDescription)")
        }
    }
    
    func makeUniformBufferSet() -> UniformBufferSet {
        return GenericUniformBufferSet(frames: RenderEngine.configurations.maxFramesInFlight, backend: self)
    }
    
    func makeTexture(from descriptor: TextureDescriptor) -> GPUTexture {
        do {
            return try VulkanGPUTexture(device: self.context.logicalDevice, descriptor: descriptor)
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
