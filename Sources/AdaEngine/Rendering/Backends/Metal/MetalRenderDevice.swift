//
//  MetalRenderDevice.swift
//  AdaEngine
//
//  Created by vladislav.prusakov on 29.08.2024.
//

#if METAL
import MetalKit

final class MetalRenderDevice: RenderDevice {

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
        let spirvShader = try shader.spirvCompiler.compile()
        let library = try self.device.makeLibrary(source: spirvShader.source, options: nil)

        let descriptor = MTLFunctionDescriptor()
        descriptor.name = spirvShader.entryPoints[0].name
        let function = try library.makeFunction(descriptor: descriptor)

        return MetalShader(name: spirvShader.entryPoints[0].name, library: library, function: function)
    }

    func createFramebuffer(from descriptor: FramebufferDescriptor) -> Framebuffer {
        return MetalFramebuffer(descriptor: descriptor)
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
        if let shader = descriptor.vertex?.compiledShader as? MetalShader {
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
            fatalError("[Metal Render Backend] \(error.localizedDescription)")
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

    func createIndexBuffer(format: IndexBufferFormat, bytes: UnsafeRawPointer, length: Int) -> IndexBuffer {
        let buffer = self.device.makeBuffer(length: length, options: .storageModeShared)!
        buffer.contents().copyMemory(from: bytes, byteCount: length)

        return MetalIndexBuffer(buffer: buffer, indexFormat: format)
    }

    func createVertexBuffer(length: Int, binding: Int) -> VertexBuffer {
        let buffer = self.device.makeBuffer(length: length, options: .storageModeShared)!
        return MetalVertexBuffer(buffer: buffer, binding: 0, offset: 0)
    }

    func createBuffer(length: Int, options: ResourceOptions) -> Buffer {
        let buffer = self.device.makeBuffer(length: length, options: options.metal)!
        return MetalBuffer(buffer: buffer)
    }

    func createBuffer(bytes: UnsafeRawPointer, length: Int, options: ResourceOptions) -> Buffer {
        let buffer = self.device.makeBuffer(bytes: bytes, length: length, options: options.metal)!
        return MetalBuffer(buffer: buffer)
    }
}


// MARK: Texture

extension MetalRenderDevice {
    // swiftlint:disable:next function_body_length cyclomatic_complexity
    func createTexture(from descriptor: TextureDescriptor) -> GPUTexture {
        let textureDesc = MTLTextureDescriptor()

        switch descriptor.textureType {
        case .textureCube:
            textureDesc.textureType = .typeCube
        case .texture1D:
            textureDesc.textureType = .type1D
        case .texture1DArray:
            textureDesc.textureType = .type1DArray
        case .texture2D:
            textureDesc.textureType = .type2D
        case .texture2DArray:
            textureDesc.textureType = .type2DArray
        case .texture2DMultisample:
            textureDesc.textureType = .type2DMultisample
        case .texture2DMultisampleArray:
            textureDesc.textureType = .type2DMultisampleArray
        case .texture3D:
            textureDesc.textureType = .type3D
        case .textureBuffer:
            textureDesc.textureType = .typeTextureBuffer
        }

        var mtlUsage: MTLTextureUsage = []

        if descriptor.textureUsage.contains(.read) {
            mtlUsage.insert(.shaderRead)
        }

        if descriptor.textureUsage.contains(.write) {
            mtlUsage.insert(.shaderWrite)
        }

        if descriptor.textureUsage.contains(.renderTarget) {
            mtlUsage.insert(.renderTarget)
        }

        textureDesc.usage = mtlUsage
        textureDesc.width = descriptor.width
        textureDesc.height = descriptor.height
        textureDesc.pixelFormat = descriptor.pixelFormat.toMetal

        guard let texture = self.device.makeTexture(descriptor: textureDesc) else {
            fatalError("Cannot create texture")
        }

        texture.label = descriptor.debugLabel

        if let image = descriptor.image {
            let region = MTLRegion(
                origin: MTLOrigin(x: 0, y: 0, z: 0),
                size: MTLSize(width: image.width, height: image.height, depth: 1)
            )

            let bytesPerRow = descriptor.pixelFormat.bytesPerComponent * image.width

            image.data.withUnsafeBytes { buffer in
                precondition(buffer.baseAddress != nil, "Image should not contains empty address.")

                texture.replace(
                    region: region,
                    mipmapLevel: 0,
                    withBytes: buffer.baseAddress!,
                    bytesPerRow: bytesPerRow
                )
            }
        }

        return MetalGPUTexture(texture: texture)
    }

    // TODO: (Vlad) think about it later
    func getImage(from texture: Texture) -> Image? {
        guard let mtlTexture = (texture.gpuTexture as? MetalGPUTexture)?.texture else {
            return nil
        }

        if mtlTexture.isFramebufferOnly {
            return nil
        }

        let imageFormat: Image.Format
        let bytesInPixel: Int

        switch mtlTexture.pixelFormat {
        case .bgra8Unorm:
            imageFormat = .bgra8
            bytesInPixel = 4
        default:
            imageFormat = .rgba8
            bytesInPixel = 4
        }

        let bytesPerRow = mtlTexture.width * bytesInPixel
        let pixelCount = mtlTexture.width * mtlTexture.height

        var imageBytes = [UInt8](repeating: 0, count: pixelCount * bytesInPixel)
        mtlTexture.getBytes(
            &imageBytes,
            bytesPerRow: bytesPerRow,
            from: MTLRegion(
                origin: MTLOrigin(x: 0, y: 0, z: 0),
                size: MTLSize(width: mtlTexture.width, height: mtlTexture.height, depth: 1)
            ),
            mipmapLevel: 0
        )

        return Image(width: mtlTexture.width, height: mtlTexture.height, data: Data(imageBytes), format: imageFormat)
    }
}

// MARK: - Drawings

extension MetalRenderDevice {

    enum DrawListError: String, LocalizedError {
        case notAGlobalDevice = "RenderDevice isn't a global."
        case windowNotExists = "Required window doesn't exists."
        case failedToGetSurfaceTexture = "Failed to get surface texture."
        case failedToCreateCommandBuffer = "Failed to create command buffer"
        case failedToGetRenderPass = "Cannot get a render pass descriptor for current draw"

        var errorDescription: String? {
            return self.rawValue
        }
    }

    func beginDraw(
        for window: UIWindow.ID,
        clearColor: Color,
        loadAction: AttachmentLoadAction,
        storeAction: AttachmentStoreAction
    ) throws -> DrawList {
        guard let context else {
            throw DrawListError.notAGlobalDevice
        }
        guard let window = context.windows[window] else {
            throw DrawListError.windowNotExists
        }
        guard let mtlRenderPass = window.getRenderPass() else {
            throw DrawListError.failedToGetSurfaceTexture
        }
        
        mtlRenderPass.colorAttachments[0].loadAction = loadAction.toMetal
        mtlRenderPass.colorAttachments[0].storeAction = storeAction.toMetal
        mtlRenderPass.colorAttachments[0].clearColor = clearColor.toMetalClearColor
        guard let mtlCommandBuffer = self.commandQueue.makeCommandBuffer() else {
            throw DrawListError.failedToCreateCommandBuffer
        }

        let encoder = mtlCommandBuffer.makeRenderCommandEncoder(descriptor: mtlRenderPass)!
        let commandBuffer = MetalRenderCommandBuffer(
            encoder: encoder,
            commandBuffer: mtlCommandBuffer
        )

        return DrawList(commandBuffer: commandBuffer, renderDevice: self)
    }

    func beginDraw(to framebuffer: Framebuffer, clearColors: [Color]?) throws -> DrawList {
        guard let mtlCommandBuffer = self.commandQueue.makeCommandBuffer() else {
            throw DrawListError.failedToCreateCommandBuffer
        }
        guard let mtlRenderPassDesc = (framebuffer as? MetalFramebuffer)?.renderPassDescriptor else {
            throw DrawListError.failedToGetRenderPass
        }

        if let clearColors {
            for (index, color) in clearColors.enumerated() {
                mtlRenderPassDesc.colorAttachments[index].clearColor = color.toMetalClearColor
            }
        }

        let encoder = mtlCommandBuffer.makeRenderCommandEncoder(descriptor: mtlRenderPassDesc)!
        let commandBuffer = MetalRenderCommandBuffer(
            encoder: encoder,
            commandBuffer: mtlCommandBuffer
        )

        return DrawList(commandBuffer: commandBuffer, renderDevice: self)
    }

    // MARK: - Uniforms -

    func createUniformBufferSet() -> UniformBufferSet {
        return MetalUniformBufferSet(frames: RenderEngine.configurations.maxFramesInFlight, device: self)
    }

    func createUniformBuffer(length: Int, binding: Int) -> UniformBuffer {
        let buffer = self.device.makeBuffer(
            length: length,
            options: .storageModeShared
        )!

        let uniformBuffer = MetalUniformBuffer(buffer: buffer, binding: binding)
        return uniformBuffer
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func draw(_ list: DrawList, indexCount: Int, indexBufferOffset: Int, instanceCount: Int) {
        guard let renderPipeline = (list.renderPipeline as? MetalRenderPipeline) else {
            fatalError("Draw doesn't have a pipeline state")
        }

        guard let encoder = (list.commandBuffer as? MetalRenderCommandBuffer)?.encoder else {
            fatalError("Command buffer")
        }

        if let name = list.debugName {
            encoder.label = name
        }

        if let depthStencilState = renderPipeline.depthStencilState {
            encoder.setDepthStencilState(depthStencilState)
        }

        // Should be in draw settings
        encoder.setCullMode(renderPipeline.descriptor.backfaceCulling ? .back : .front)

        encoder.setFrontFacing(.counterClockwise)

        encoder.setRenderPipelineState(renderPipeline.renderPipeline)

        if list.isScissorEnabled {
            let rect = list.scissorRect

            encoder.setScissorRect(
                MTLScissorRect(
                    x: Int(rect.origin.x),
                    y: Int(rect.origin.y),
                    width: Int(rect.size.width),
                    height: Int(rect.size.height)
                )
            )
        }

        if list.isViewportEnabled {
            let viewport = list.viewport
            let rect = viewport.rect

            encoder.setViewport(
                MTLViewport(
                    originX: Double(rect.origin.x),
                    originY: Double(rect.origin.y),
                    width: Double(rect.size.width),
                    height: Double(rect.size.height),
                    znear: Double(viewport.depth.lowerBound),
                    zfar: Double(viewport.depth.upperBound)
                )
            )
        }

        guard let indexBuffer = list.indexBuffer else {
            fatalError("can't draw without index buffer")
        }

        for buffer in list.vertexBuffers {
            let vertexBuffer = buffer as! MetalVertexBuffer
            encoder.setVertexBuffer(vertexBuffer.buffer, offset: 0, index: vertexBuffer.binding)
        }

        let textures = list.textures.compactMap { $0 }
        for (index, texture) in textures.enumerated() {
            let mtlTexture = (texture.gpuTexture as! MetalGPUTexture).texture
            let mtlSampler = (texture.sampler as! MetalSampler).mtlSampler

            encoder.setFragmentTexture(mtlTexture, index: index)
            encoder.setFragmentSamplerState(mtlSampler, index: index)
        }

        for index in 0 ..< list.uniformBufferCount {
            let data = list.uniformBuffers[index]!
            let buffer = data.buffer as! MetalUniformBuffer

            switch data.shaderStage {
            case .vertex:
                encoder.setVertexBuffer(buffer.buffer, offset: 0, index: buffer.binding)
            case .fragment:
                encoder.setFragmentBuffer(buffer.buffer, offset: 0, index: buffer.binding)
            default:
                continue
            }
        }

        encoder.setTriangleFillMode(list.triangleFillMode == .fill ? .fill : .lines)

        encoder.drawIndexedPrimitives(
            type: list.indexPrimitive.toMetal,
            indexCount: indexCount,
            indexType: indexBuffer.indexFormat == .uInt32 ? .uint32 : .uint16,
            indexBuffer: (indexBuffer as! MetalIndexBuffer).buffer,
            indexBufferOffset: indexBufferOffset,
            instanceCount: instanceCount
        )
    }

    func endDrawList(_ drawList: DrawList) {
        guard let commandBuffer = drawList.commandBuffer as? MetalRenderCommandBuffer else {
            return
        }

        commandBuffer.encoder.endEncoding()
        commandBuffer.commandBuffer.commit()
    }
}

#endif