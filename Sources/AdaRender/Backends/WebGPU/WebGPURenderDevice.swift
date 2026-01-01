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
        fatalError()
    }

    func createVertexBuffer(label: String?, length: Int, binding: Int) -> any VertexBuffer {
        fatalError()
    }

    func createIndexBuffer(label: String?, format: IndexBufferFormat, bytes: UnsafeRawPointer, length: Int) -> any IndexBuffer {
        fatalError()
    }

    func createBuffer(label: String?, bytes: UnsafeRawPointer, length: Int, options: ResourceOptions) -> any Buffer {
        fatalError()
    }

    func createBuffer(label: String?, length: Int, options: ResourceOptions) -> any Buffer {
        fatalError()
    }

    func compileShader(from shader: Shader) throws -> any CompiledShader {
        fatalError()
    }

    func createFramebuffer(from descriptor: FramebufferDescriptor) -> any Framebuffer {
        fatalError()
    }

    func createRenderPipeline(from descriptor: RenderPipelineDescriptor) -> any RenderPipeline {
        fatalError()
    }

    func createSampler(from descriptor: SamplerDescriptor) -> any Sampler {
        fatalError()
    }

    func createUniformBufferSet() -> any UniformBufferSet {
        fatalError()
    }

    func createTexture(from descriptor: TextureDescriptor) -> any GPUTexture {
        fatalError()
    }

    func getImage(from texture: Texture) -> Image? {
        fatalError()
    }

    func createCommandQueue() -> any CommandQueue {
        fatalError()
    }

    func createSwapchain(from window: WindowID) -> any Swapchain {
        fatalError()
    }
}

#endif
