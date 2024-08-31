//
//  VulkanRenderDevice.swift
//  AdaEngine
//
//  Created by vladislav.prusakov on 31.08.2024.
//

#if VULKAN
import CVulkan
import Vulkan

final class VulkanRenderDevice: RenderDevice {

    let device: Device
    let commandPool: CommandPool
    let context: VulkanRenderBackend.Context?

    init(device: Device, commandPool: CommandPool, context: VulkanRenderBackend.Context? = nil) {
        self.device = device
        self.commandPool = commandPool
        self.context = context
    }

    func getImage(from texture: Texture) -> Image? {
        return nil
    }

    func createIndexBuffer(format: IndexBufferFormat, bytes: UnsafeRawPointer, length: Int) -> IndexBuffer {
        do {
            let indexBuffer = try VulkanIndexBuffer(renderDevice: self, size: length, queueFamilyIndecies: [], indexFormat: format)
            let rawPointer = UnsafeMutableRawPointer(mutating: bytes)
            indexBuffer.setData(rawPointer, byteCount: length)
            return indexBuffer
        } catch {
            fatalError("\(error.localizedDescription)")
        }
    }

    func createBuffer(length: Int, options: ResourceOptions) -> Buffer {
        do {
            return try VulkanBuffer(
                renderDevice: self,
                size: length,
                usage: VK_BUFFER_USAGE_STORAGE_BUFFER_BIT.rawValue,
                queueFamilyIndecies: []
            )
        } catch {
            fatalError("\(error.localizedDescription)")
        }
    }

    func createBuffer(bytes: UnsafeRawPointer, length: Int, options: ResourceOptions) -> Buffer {
        do {
            let buffer = try VulkanBuffer(
                renderDevice: self,
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

    func createVertexBuffer(length: Int, binding: Int) -> VertexBuffer {
        do {
            return try VulkanVertexBuffer(
                renderDevice: self,
                size: length,
                queueFamilyIndecies: [],
                binding: binding
            )
        } catch {
            fatalError("\(error.localizedDescription)")
        }
    }

    func compileShader(from shader: Shader) throws -> CompiledShader {
        return try VulkanShader.make(from: shader, device: self.device)
    }

    func createFramebuffer(from descriptor: FramebufferDescriptor) -> Framebuffer {
        return VulkanFramebuffer(device: self.device, descriptor: descriptor)
    }

    func createRenderPipeline(from descriptor: RenderPipelineDescriptor) -> RenderPipeline {
        do {
            return try VulkanRenderPipeline(device: self.device, descriptor: descriptor)
        } catch {
            fatalError("\(error.localizedDescription)")
        }
    }

    func createSampler(from descriptor: SamplerDescriptor) -> Sampler {
        do {
            return try VulkanSampler(device: self.device, descriptor: descriptor)
        } catch {
            fatalError("\(error.localizedDescription)")
        }
    }

    func createUniformBuffer(length: Int, binding: Int) -> UniformBuffer {
        do {
            return try VulkanUniformBuffer(renderDevice: self, size: length, queueFamilyIndecies: [], binding: binding)
        } catch {
            fatalError("\(error.localizedDescription)")
        }
    }

    func createUniformBufferSet() -> UniformBufferSet {
        return GenericUniformBufferSet(frames: RenderEngine.configurations.maxFramesInFlight, device: self)
    }

    func createTexture(from descriptor: TextureDescriptor) -> GPUTexture {
        do {
            return try VulkanGPUTexture(device: self.device, descriptor: descriptor)
        } catch {
            fatalError("[VulkanRenderBackend] Failed to create texture: \(error.localizedDescription)")
        }
    }

    func getImage(for texture2D: RID) -> Image? {
        fatalError("Kek")
    }

    func beginDraw(
        for window: UIWindow.ID,
        clearColor: Color,
        loadAction: AttachmentLoadAction,
        storeAction: AttachmentStoreAction
    ) throws -> DrawList {
        guard let window = self.context?.windows[window] else {
            fatalError("Can't find window for draw")
        }

        let framebuffer = window.swapchain.framebuffers[RenderEngine.shared.currentFrameIndex]
        let vkFramebuffer = VulkanFramebuffer(
            device: self.device,
            framebuffer: framebuffer,
            renderPass: window.swapchain.renderPass
        )
        return DrawList(commandBuffer: VulkanRenderCommandBuffer(framebuffer: vkFramebuffer), renderDevice: self)
    }

    func beginDraw(to framebuffer: Framebuffer, clearColors: [Color]?) throws -> DrawList {
        guard let vulkanFramebuffer = framebuffer as? VulkanFramebuffer else {
            fatalError("Not correct framebuffer object")
        }

        return DrawList(commandBuffer: VulkanRenderCommandBuffer(framebuffer: vulkanFramebuffer), renderDevice: self)
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

    func endDrawList(_ drawList: DrawList) {

    }
}

#endif
