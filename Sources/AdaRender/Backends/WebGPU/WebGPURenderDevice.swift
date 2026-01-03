//
//  WebGPURenderDevice.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 28.12.2025.
//

#if canImport(WebGPU)
import WebGPU

final class WebGPURenderDevice: RenderDevice, @unchecked Sendable {

    private let context: WGPUContext

    init(context: WGPUContext) {
        self.context = context
    }

    func createUniformBuffer(length: Int, binding: Int) -> any UniformBuffer {
        // TODO: Implement WebGPU buffer creation
        fatalError("createUniformBuffer not yet implemented for WebGPU")
    }

    func createVertexBuffer(label: String?, length: Int, binding: Int) -> any VertexBuffer {
        // TODO: Implement WebGPU buffer creation
        fatalError("createVertexBuffer not yet implemented for WebGPU")
    }

    func createIndexBuffer(label: String?, format: IndexBufferFormat, bytes: UnsafeRawPointer, length: Int) -> any IndexBuffer {
        // TODO: Implement WebGPU buffer creation
        fatalError("createIndexBuffer not yet implemented for WebGPU")
    }

    func createBuffer(label: String?, bytes: UnsafeRawPointer, length: Int, options: ResourceOptions) -> any Buffer {
        // TODO: Implement WebGPU buffer creation
        fatalError("createBuffer(bytes:) not yet implemented for WebGPU")
    }

    func createBuffer(label: String?, length: Int, options: ResourceOptions) -> any Buffer {
        // TODO: Implement WebGPU buffer creation
        fatalError("createBuffer(length:) not yet implemented for WebGPU")
    }

    func compileShader(from shader: Shader) throws -> any CompiledShader {
        // TODO: Implement WebGPU shader compilation
        fatalError("compileShader not yet implemented for WebGPU")
    }

    func createRenderPipeline(from descriptor: RenderPipelineDescriptor) -> any RenderPipeline {
        // TODO: Fix WGPURenderPipeline to use WebGPU instead of Metal
        fatalError("createRenderPipeline not yet implemented for WebGPU")
    }

    func createSampler(from descriptor: SamplerDescriptor) -> any Sampler {
        // TODO: Fix WGPUSampler to use WebGPU instead of Metal
        fatalError("createSampler not yet implemented for WebGPU")
    }

    func createUniformBufferSet() -> any UniformBufferSet {
        return GenericUniformBufferSet(frames: RenderEngine.configurations.maxFramesInFlight, device: self)
    }

    func createTexture(from descriptor: TextureDescriptor) -> any GPUTexture {
        // TODO: Fix WGPUGPUTexture to use WebGPU instead of Metal
        fatalError("createTexture not yet implemented for WebGPU")
    }

    func getImage(from texture: Texture) -> Image? {
        return (texture.gpuTexture as? WGPUGPUTexture)?.getImage()
    }

    func createCommandQueue() -> any CommandQueue {
        return WGPUCommandQueue(commandQueue: context.device.queue)
    }

    @MainActor
    func createSwapchain(from window: WindowID) -> any Swapchain {
        // TODO: Implement WebGPU swapchain creation
        fatalError("createSwapchain not yet implemented for WebGPU")
    }
}

#endif
