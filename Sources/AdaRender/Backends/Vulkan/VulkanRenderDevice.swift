//
//  VulkanRenderDevice.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 01.03.2025.
//

#if VULKAN
import Vulkan
import CVulkan

final class VulkanRenderDevice: RenderDevice {
    
    var context: VulkanRenderBackend.Context
    
    init(context: VulkanRenderBackend.Context) {
        self.context = context
    }
    
    func getImage(from texture: Texture) -> Image? {
        return nil
    }

    func createIndexBuffer(format: IndexBufferFormat, bytes: UnsafeRawPointer, length: Int) -> any IndexBuffer {
        do {
            let indexBuffer = try VulkanIndexBuffer(
                logicalDevice: self.context.logicalDevice,
                size: length,
                renderDevice: self,
                queueFamilyIndecies: [],
                indexFormat: format
            )
            let rawPointer = UnsafeMutableRawPointer(mutating: bytes)
            indexBuffer.setData(rawPointer, byteCount: length)
            return indexBuffer
        } catch {
            fatalError("\(error)")
        }
    }

    func createBuffer(length: Int, options: ResourceOptions) -> Buffer {
        do {
            return try VulkanBuffer(
                logicalDevice: self.context.logicalDevice,
                size: length,
                usage: VK_BUFFER_USAGE_STORAGE_BUFFER_BIT.rawValue,
                renderDevice: self,
                queueFamilyIndecies: []
            )
        } catch {
            fatalError("\(error)")
        }
    }

    func createBuffer(bytes: UnsafeRawPointer, length: Int, options: ResourceOptions) -> Buffer {
        do {
            let buffer = try VulkanBuffer(
                logicalDevice: self.context.logicalDevice,
                size: length,
                usage: VK_BUFFER_USAGE_STORAGE_BUFFER_BIT.rawValue,
                renderDevice: self,
                queueFamilyIndecies: []
            )
            buffer.setData(UnsafeMutableRawPointer(mutating: bytes), byteCount: length)

            return buffer
        } catch {
            fatalError("\(error)")
        }
    }

    func createVertexBuffer(length: Int, binding: Int) -> VertexBuffer {
        do {
            return try VulkanVertexBuffer(
                logicalDevice: self.context.logicalDevice,
                size: length,
                renderDevice: self,
                queueFamilyIndecies: [],
                binding: binding
            )
        } catch {
            fatalError("\(error)")
        }
    }
    
    func compileShader(from shader: Shader) throws -> CompiledShader {
        return try VulkanShader.make(from: shader, device: self.context.logicalDevice)
    }
    
    func createFramebuffer(from descriptor: FramebufferDescriptor) -> Framebuffer {
        return VulkanFramebuffer(device: self.context.logicalDevice, descriptor: descriptor)
    }
    
    func createRenderPipeline(from descriptor: RenderPipelineDescriptor) -> RenderPipeline {
        do {
            return try VulkanRenderPipeline(device: self.context.logicalDevice, descriptor: descriptor)
        } catch {
            fatalError("\(error)")
        }
    }
    
    func createSampler(from descriptor: SamplerDescriptor) -> Sampler {
        do {
            return try VulkanSampler(device: self.context.logicalDevice, descriptor: descriptor)
        } catch {
            fatalError("\(error)")
        }
    }
    
    func createUniformBuffer(length: Int, binding: Int) -> UniformBuffer {
        do {
            return try VulkanUniformBuffer(
                logicalDevice: self.context.logicalDevice,
                size: length,
                renderDevice: self,
                queueFamilyIndecies: [],
                binding: binding
            )
        } catch {
            fatalError("\(error)")
        }
    }
    
    func createUniformBufferSet() -> UniformBufferSet {
        return GenericUniformBufferSet(frames: RenderEngine.configurations.maxFramesInFlight, device: self)
    }
    
    func createTexture(from descriptor: TextureDescriptor) -> GPUTexture {
        do {
            return try VulkanGPUTexture(device: self.context.logicalDevice, descriptor: descriptor)
        } catch {
            fatalError("[VulkanRenderBackend] Failed to create texture: \(error)")
        }
    }
    
    func getImage(for texture2D: RID) -> Image? {
        fatalError("Kek")
    }
    
    func draw(_ list: DrawList, indexCount: Int, indexBufferOffset: Int, instanceCount: Int) {
        guard let renderPipeline = list.renderPipeline as? VulkanRenderPipeline else {
            return
        }
        
        guard let renderCommandBuffer = list.commandBuffer as? VulkanRenderCommandBuffer else {
            return
        }
        
        do {
            // Prepare render pipeline
            try renderPipeline.update(
                for: renderCommandBuffer.framebuffer,
                drawList: list
            )
            
        } catch {
            assertionFailure("Failed to draw: \(error)")
        }
    }
    
    func beginDraw(to framebuffer: Framebuffer, clearColors: [Color]?) -> DrawList {
        guard let vulkanFramebuffer = framebuffer as? VulkanFramebuffer else {
            fatalError("Not correct framebuffer object")
        }
        
        return DrawList(
            commandBuffer: VulkanRenderCommandBuffer(framebuffer: vulkanFramebuffer),
            renderDevice: self
        )
    }

    func beginDraw(
        for window: UIWindow.ID,
        clearColor: Color,
        loadAction: AttachmentLoadAction,
        storeAction: AttachmentStoreAction
    ) throws -> DrawList {
        guard let window = self.context.windows[window] else {
            fatalError("Can't find window for draw")
        }
        
        let framebuffer = window.swapchain.framebuffers[0]
        let vkFramebuffer = VulkanFramebuffer(
            device: self.context.logicalDevice,
            framebuffer: framebuffer,
            renderPass: window.swapchain.renderPass
        )
        return DrawList(
            commandBuffer: VulkanRenderCommandBuffer(framebuffer: vkFramebuffer),
            renderDevice: self
        )
    }
    
    func endDrawList(_ drawList: DrawList) {
        
    }
}

#endif
