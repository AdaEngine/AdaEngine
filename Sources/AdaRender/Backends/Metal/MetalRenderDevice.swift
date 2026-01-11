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

    enum RenderDeviceError: LocalizedError {
        case shaderSourceIsNotCode

        var errorDescription: String? {
        switch self {
        case .shaderSourceIsNotCode:
            return "Shader source is not a code"
        }
    }
    }

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
        guard case let .code(source) = shader.source else {
            throw RenderDeviceError.shaderSourceIsNotCode
        }
        let library = try self.device.makeLibrary(source: source, options: nil)
        let descriptor = MTLFunctionDescriptor()
        descriptor.name = shader.entryPoint
        let function = try library.makeFunction(descriptor: descriptor)
        return MetalShader(name: shader.entryPoint, library: library, function: function)
    }

    func createCommandQueue() -> CommandQueue {
        return MetalCommandQueue(commandQueue: self.commandQueue)
    }

    // swiftlint:disable:next function_body_length
    func createRenderPipeline(from descriptor: RenderPipelineDescriptor) -> RenderPipeline {
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.label = descriptor.debugName

        let vertexDescriptor = MTLVertexDescriptor()

        for (index, attribute) in descriptor.vertexDescriptor.attributes.enumerated() {
            vertexDescriptor.attributes[index].offset = attribute.offset
            vertexDescriptor.attributes[index].bufferIndex = attribute.bufferIndex
            vertexDescriptor.attributes[index].format = attribute.format.metalFormat
        }

        for (index, layout) in descriptor.vertexDescriptor.layouts.enumerated() {
            vertexDescriptor.layouts[index].stride = layout.stride
        }
        if let shader = descriptor.vertex.compiledShader as? MetalShader {
            pipelineDescriptor.vertexFunction = shader.function
        }

        if let shader = descriptor.fragment?.compiledShader as? MetalShader {
            pipelineDescriptor.fragmentFunction = shader.function
        }

        pipelineDescriptor.vertexDescriptor = vertexDescriptor

        for (index, attachment) in descriptor.colorAttachments.enumerated() {
            let colorAttachment = pipelineDescriptor.colorAttachments[index]!

            colorAttachment.pixelFormat = attachment.format.toMetal
            colorAttachment.isBlendingEnabled = attachment.isBlendingEnabled
            colorAttachment.rgbBlendOperation = attachment.rgbBlendOperation.toMetal
            colorAttachment.alphaBlendOperation = attachment.alphaBlendOperation.toMetal
            colorAttachment.sourceRGBBlendFactor = attachment.sourceRGBBlendFactor.toMetal
            colorAttachment.sourceAlphaBlendFactor = attachment.sourceAlphaBlendFactor.toMetal
            colorAttachment.destinationRGBBlendFactor = attachment.destinationRGBBlendFactor.toMetal
            colorAttachment.destinationAlphaBlendFactor = attachment.destinationAlphaBlendFactor.toMetal
        }

        var depthStencilState: MTLDepthStencilState?

        if let depthStencilDesc = descriptor.depthStencilDescriptor {
            pipelineDescriptor.depthAttachmentPixelFormat = descriptor.depthPixelFormat.toMetal
            pipelineDescriptor.stencilAttachmentPixelFormat = descriptor.depthPixelFormat.toMetal

            let depthStencilDescriptor = MTLDepthStencilDescriptor()
            depthStencilDescriptor.depthCompareFunction = depthStencilDesc.depthCompareOperator.toMetal
            depthStencilDescriptor.isDepthWriteEnabled = depthStencilDesc.isDepthWriteEnabled

            if depthStencilDesc.isEnableStencil {
                guard let stencilDesc = depthStencilDesc.stencilOperationDescriptor else {
                    fatalError("StencilOperationDescriptor instance not passed to DepthStencilDescriptor object.")
                }

                let stencilDescriptor = MTLStencilDescriptor()
                stencilDescriptor.depthFailureOperation = stencilDesc.depthFail.toMetal
                stencilDescriptor.depthStencilPassOperation = stencilDesc.pass.toMetal
                stencilDescriptor.stencilFailureOperation = stencilDesc.fail.toMetal
                stencilDescriptor.stencilCompareFunction = stencilDesc.compare.toMetal

                depthStencilDescriptor.backFaceStencil = stencilDescriptor
                depthStencilDescriptor.frontFaceStencil = stencilDescriptor
            }

            depthStencilState = self.device.makeDepthStencilState(descriptor: depthStencilDescriptor)
        }

        do {
            let state = try self.device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            return MetalRenderPipeline(
                descriptor: descriptor,
                renderPipeline: state,
                depthState: depthStencilState
            )
        } catch {
            fatalError("[Metal Render Backend] \(error)")
        }
    }

    func createSampler(from descriptor: SamplerDescriptor) -> Sampler {
        let mtlDescriptor = MTLSamplerDescriptor()
        mtlDescriptor.minFilter = descriptor.minFilter.toMetal
        mtlDescriptor.magFilter = descriptor.magFilter.toMetal
        mtlDescriptor.lodMinClamp = descriptor.lodMinClamp
        mtlDescriptor.lodMaxClamp = descriptor.lodMaxClamp

        switch descriptor.mipFilter {
        case .nearest:
            mtlDescriptor.mipFilter = .nearest
        case .linear:
            mtlDescriptor.mipFilter = .linear
        case .notMipmapped:
            mtlDescriptor.mipFilter = .notMipmapped
        }

        let sampler = self.device.makeSamplerState(descriptor: mtlDescriptor)!
        return MetalSampler(descriptor: descriptor, mtlSampler: sampler)
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
