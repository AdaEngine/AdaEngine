//
//  MetalRenderDevice.swift
//  AdaEngine
//
//  Created by vladislav.prusakov on 29.08.2024.
//

#if METAL
import AdaUtils
import Metal
@unsafe @preconcurrency import MetalKit
import Math

final class MetalRenderDevice: RenderDevice, @unchecked Sendable {

    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    private weak var context: MetalRenderBackend.Context?

    init(
        device: MTLDevice,
        commandQueue: MTLCommandQueue,
        context: MetalRenderBackend.Context? = nil
    ) {
        self.device = device
        self.commandQueue = commandQueue
        self.context = context
    }

    func compileShader(from shader: Shader) throws -> CompiledShader {
        return try MetalShader(shader: shader, device: self.device)
    }

    func createCommandQueue() -> CommandQueue {
        return MetalCommandQueue(commandQueue: self.commandQueue)
    }

    // swiftlint:disable:next function_body_length
    func createRenderPipeline(from descriptor: RenderPipelineDescriptor) -> RenderPipeline {
        do {
            return try MetalRenderPipeline(descriptor: descriptor, device: device)
        } catch {
            fatalError("[Metal Render Backend] \(error)")
        }
    }

    func createSampler(from descriptor: SamplerDescriptor) -> Sampler {
        return MetalSampler(descriptor: descriptor, device: device)
    }

    // MARK: - Buffers

    func createIndexBuffer(label: String?, format: IndexBufferFormat, bytes: UnsafeRawPointer, length: Int) -> IndexBuffer {
        let buffer = self.device.makeBuffer(length: length, options: .storageModeShared)!
        unsafe buffer.contents().copyMemory(from: bytes, byteCount: length)
        let metalBuffer = MetalIndexBuffer(buffer: buffer, indexFormat: format)
        metalBuffer.label = label
        return metalBuffer
    }

    func createVertexBuffer(label: String?, length: Int, binding: Int) -> VertexBuffer {
        let buffer = self.device.makeBuffer(length: length, options: .storageModeShared)!
        let metalBuffer = MetalVertexBuffer(buffer: buffer, binding: 0, offset: 0)
        metalBuffer.label = label
        return metalBuffer
    }

    func createBuffer(label: String?, length: Int, options: ResourceOptions) -> Buffer {
        let buffer = self.device.makeBuffer(length: length, options: options.metal)!
        let metalBuffer = MetalBuffer(buffer: buffer)
        metalBuffer.label = label
        return metalBuffer
    }

    func createBuffer(label: String?, bytes: UnsafeRawPointer, length: Int, options: ResourceOptions) -> Buffer {
        let buffer = unsafe self.device.makeBuffer(bytes: bytes, length: length, options: options.metal)!
        let metalBuffer = MetalBuffer(buffer: buffer)
        metalBuffer.label = label
        return metalBuffer
    }

    @MainActor
    func createSwapchain(from window: WindowID) -> any Swapchain {
        guard let context else {
            fatalError("Context not found")
        }
        let window = context.getRenderWindow(for: window)
            .unwrap(message: "RenderWindow not found")

        return require(window.view.layer as? CAMetalLayer, message: "Expected that view layer is CAMetalLayer")
    }
}

extension CAMetalLayer: Swapchain {
    public var drawablePixelFormat: PixelFormat {
        self.pixelFormat.toPixelFormat()
    }

    public func getNextDrawable(_ renderDevice: RenderDevice) -> (any Drawable)? {
        guard
            let drawable = self.nextDrawable(),
            let mtlDevice = renderDevice as? MetalRenderDevice
        else {
            return nil
        }
        return MetalDrawable(drawable: drawable, commandQueue: mtlDevice.commandQueue)
    }
}

extension MTLPixelFormat {
    func toPixelFormat() -> PixelFormat {
        switch self {
        case .bgra8Unorm:
            return .bgra8
        case .bgra8Unorm_srgb:
            return .bgra8_srgb
        case .rgba8Unorm:
            return .rgba8
        case .rgba8Uint:
            return .rgba8
        case .rgba16Float:
            return .rgba_16f
        case .rgba32Float:
            return .rgba_32f
        case .depth32Float:
            return .depth_32f
        case .depth32Float_stencil8:
            return .depth_32f_stencil8
        default:
            fatalError("Unsupported pixel format: \(self)")
        }
    }
}

final class MetalDrawable: Drawable {
    private let commandQueue: MTLCommandQueue
    private let mtlDrawable: CAMetalDrawable

    public var texture: any GPUTexture {
        MetalGPUTexture(texture: self.mtlDrawable.texture)
    }

    public func present() throws {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }
        commandBuffer.label = "(AdaRender internal) Present"
        commandBuffer.present(self.mtlDrawable)
        commandBuffer.commit()
    }

    init(drawable: CAMetalDrawable, commandQueue: MTLCommandQueue) {
        self.commandQueue = commandQueue
        self.mtlDrawable = drawable
    }
}

// MARK: Texture

extension MetalRenderDevice {
    func createTexture(from descriptor: TextureDescriptor) -> GPUTexture {
        return MetalGPUTexture(descriptor: descriptor, device: self.device)
    }

    func getImage(from texture: Texture) -> Image? {
        (texture.gpuTexture as? MetalGPUTexture)?.getImage()
    }
}

// MARK: - Drawings

extension MetalRenderDevice {
    func createUniformBufferSet() -> UniformBufferSet {
        return unsafe GenericUniformBufferSet(frames: RenderEngine.configurations.maxFramesInFlight, device: self)
    }

    func createUniformBuffer(length: Int, binding: Int) -> UniformBuffer {
        let buffer = self.device.makeBuffer(
            length: length,
            options: .storageModeShared
        )!

        let uniformBuffer = MetalUniformBuffer(buffer: buffer, binding: binding)
        return uniformBuffer
    }
}

#endif
