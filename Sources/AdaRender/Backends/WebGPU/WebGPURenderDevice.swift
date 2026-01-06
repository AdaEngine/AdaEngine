//
//  WebGPURenderDevice.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 28.12.2025.
//

#if canImport(WebGPU)
import AdaUtils
import WebGPU
import Foundation

final class WebGPURenderDevice: RenderDevice, @unchecked Sendable {

    private let context: WGPUContext

    init(context: WGPUContext) {
        self.context = context
    }

    func createUniformBuffer(length: Int, binding: Int) -> any UniformBuffer {
        let _buffer = context.device.createBuffer(
            descriptor: BufferDescriptor(
                usage: [WebGPU.BufferUsage.indirect, WebGPU.BufferUsage.copyDst, WebGPU.BufferUsage.copySrc, .uniform],
                size: UInt64(length)
            )
        ).unwrap(message: "Failed to create buffer")
        return WGPUUniformBuffer(buffer: _buffer, device: context.device, binding: binding)
    }

    func createVertexBuffer(label: String?, length: Int, binding: Int) -> any VertexBuffer {
        let _buffer = context.device.createBuffer(
            descriptor: BufferDescriptor(
                label: label,
                usage: [WebGPU.BufferUsage.vertex, WebGPU.BufferUsage.copyDst, WebGPU.BufferUsage.copySrc],
                size: UInt64(length)
            )
        ).unwrap(message: "Failed to create buffer")
        return WGPUVertexBuffer(buffer: _buffer, device: context.device, binding: binding, offset: 0)
    }

    func createIndexBuffer(label: String?, format: IndexBufferFormat, bytes: UnsafeRawPointer, length: Int) -> any IndexBuffer {
        let _buffer = context.device.createBuffer(
            descriptor: BufferDescriptor(
                label: label,
                usage: [WebGPU.BufferUsage.index, WebGPU.BufferUsage.copyDst],
                size: UInt64(length)
            )
        ).unwrap(message: "Failed to create buffer")
        let buffer = WGPUIndexBuffer(buffer: _buffer, device: context.device, indexFormat: format)
        unsafe buffer.setData(UnsafeMutableRawPointer(mutating: bytes), byteCount: length, offset: 0)
        return buffer
    }

    func createBuffer(label: String?, bytes: UnsafeRawPointer, length: Int, options: ResourceOptions) -> any Buffer {
        let _buffer = context.device.createBuffer(
            descriptor: BufferDescriptor(
                label: label,
                usage: options.toWebGPU,
                size: UInt64(length)
            )
        ).unwrap(message: "Failed to create buffer")
        let buffer = WGPUBuffer(buffer: _buffer, device: context.device)
        unsafe buffer.setData(UnsafeMutableRawPointer(mutating: bytes), byteCount: length, offset: 0)
        return buffer
    }

    func createBuffer(label: String?, length: Int, options: ResourceOptions) -> any Buffer {
        let buffer = context.device.createBuffer(
            descriptor: BufferDescriptor(
                label: label,
                usage: options.toWebGPU,
                size: UInt64(length)
            )
        ).unwrap(message: "Failed to create buffer")
        return WGPUBuffer(buffer: buffer, device: context.device)
    }

    func compileShader(from shader: Shader) throws -> any CompiledShader {
        return WGPUShader(shader: shader, device: context.device)
    }

    func createRenderPipeline(from descriptor: RenderPipelineDescriptor) -> any RenderPipeline {
        WGPURenderPipeline(
            descriptor: descriptor,
            device: context.device
        )
    }

    func createSampler(from descriptor: SamplerDescriptor) -> any Sampler {
        let wgpuSampler = context.device.createSampler(
            descriptor: WebGPU.SamplerDescriptor(
                label: nil,
                magFilter: descriptor.magFilter.toWebGPU,
                minFilter: descriptor.minFilter.toWebGPU,
                mipmapFilter: descriptor.mipFilter.toWebGPU,
                lodMinClamp: Float(descriptor.lodMinClamp),
                lodMaxClamp: Float(descriptor.lodMaxClamp)
            )
        )
        return WGPUSampler(descriptor: descriptor, wgpuSampler: wgpuSampler)
    }

    func createUniformBufferSet() -> any UniformBufferSet {
        return unsafe GenericUniformBufferSet(frames: RenderEngine.configurations.maxFramesInFlight, device: self)
    }

    func createTexture(from descriptor: TextureDescriptor) -> any GPUTexture {
        return WGPUGPUTexture(descriptor: descriptor, device: context.device)
    }

    func getImage(from texture: Texture) -> Image? {
        return (texture.gpuTexture as? WGPUGPUTexture)?.getImage(device: context.device)
    }

    func createCommandQueue() -> any CommandQueue {
        return WGPUCommandQueue(device: context.device)
    }

    @MainActor
    func createSwapchain(from window: WindowID) -> any Swapchain {
        WGPUSwapchain(renderWindow: context.getWGPURenderWindow(for: window)!)
    }
}

extension ResourceOptions {
    var toWebGPU: WebGPU.BufferUsage {
        switch self {
        case .storageManaged:
            [WebGPU.BufferUsage.storage, .copySrc, .copyDst, .uniform, .vertex, .index]
        case .storageShared:
            [WebGPU.BufferUsage.storage, .copySrc, .copyDst, .uniform, .vertex, .index]
        case .storagePrivate:
            [WebGPU.BufferUsage.indirect, .uniform, .vertex, .index]
        default:
            [.uniform, .vertex, .index, .copyDst]
        }
    }
}

#endif
