//
//  MetalRenderBackend.swift
//  AdaEngine
//
//  Created by v.prusakov on 10/20/21.
//

// TODO: (Vlad) We should support bgra8Unorm_srgb (Should we?)

#if METAL
import Metal
import ModelIO
import MetalKit
import OrderedCollections

class MetalRenderBackend: RenderBackend {
    
    private let context: Context
    private(set) var currentFrameIndex: Int = 0
    
    private var inFlightSemaphore: DispatchSemaphore
    private var commandQueue: MTLCommandQueue
    
    init(appName: String) {
        self.context = Context()
        
        self.inFlightSemaphore = DispatchSemaphore(value: RenderEngine.configurations.maxFramesInFlight)
        self.commandQueue = self.context.physicalDevice.makeCommandQueue()!
    }
    
    func createWindow(_ windowId: Window.ID, for view: RenderView, size: Size) throws {
        let mtlView = (view as! MetalView)
        try self.context.createRenderWindow(with: windowId, view: mtlView, size: size)
    }
    
    func resizeWindow(_ windowId: Window.ID, newSize: Size) throws {
        guard newSize.width > 0 && newSize.height > 0 else {
            return
        }
        
        self.context.updateSizeForRenderWindow(windowId, size: newSize)
    }
    
    func destroyWindow(_ windowId: Window.ID) throws {
        guard self.context.windows[windowId] != nil else {
            return
        }
        
        self.context.destroyWindow(by: windowId)
    }
    
    // FIXME: (Vlad) I'm not sure how it should works with multiple window instances.
    func beginFrame() throws {
        for (_, window) in self.context.windows {
            window.commandBuffer = self.commandQueue.makeCommandBuffer()
            window.drawable = (window.view?.layer as? CAMetalLayer)?.nextDrawable()
        }
    }
    
    func endFrame() throws {
        self.inFlightSemaphore.wait()
        
        for window in self.context.windows.values {
            guard let drawable = window.drawable, let commandBuffer = window.commandBuffer else {
                return
            }
            
            commandBuffer.addCompletedHandler { _ in
                self.inFlightSemaphore.signal()
            }
            
            commandBuffer.present(drawable)
            
            commandBuffer.commit()
        }
        
        currentFrameIndex = (currentFrameIndex + 1) % RenderEngine.configurations.maxFramesInFlight
    }
    
    func compileShader(from shader: Shader) throws -> CompiledShader {
        let spirvShader = try shader.spirvCompiler.compile()
        let library = try self.context.physicalDevice.makeLibrary(source: spirvShader.source, options: nil)
        
        let descriptor = MTLFunctionDescriptor()
        descriptor.name = spirvShader.entryPoints[0].name
        let function = try library.makeFunction(descriptor: descriptor)
        
        return MetalShader(name: spirvShader.entryPoints[0].name, library: library, function: function)
    }
    
    func makeFramebuffer(from descriptor: FramebufferDescriptor) -> Framebuffer {
        return MetalFramebuffer(descriptor: descriptor)
    }
    
    // swiftlint:disable:next function_body_length
    func makeRenderPipeline(from descriptor: RenderPipelineDescriptor) -> RenderPipeline {
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

            depthStencilState = self.context.physicalDevice.makeDepthStencilState(descriptor: depthStencilDescriptor)
        }
        
        do {
            let state = try self.context.physicalDevice.makeRenderPipelineState(descriptor: pipelineDescriptor)
            return MetalRenderPipeline(
                descriptor: descriptor,
                renderPipeline: state,
                depthState: depthStencilState
            )
        } catch {
            fatalError("[Metal Render Backend] \(error.localizedDescription)")
        }
    }
    
    func makeSampler(from descriptor: SamplerDescriptor) -> Sampler {
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
        
        let sampler = self.context.physicalDevice.makeSamplerState(descriptor: mtlDescriptor)!
        return MetalSampler(descriptor: descriptor, mtlSampler: sampler)
    }
    
    // MARK: - Buffers
    
    func makeIndexBuffer(format: IndexBufferFormat, bytes: UnsafeRawPointer, length: Int) -> IndexBuffer {
        let buffer = self.context.physicalDevice.makeBuffer(length: length, options: MTLResourceStorageModeShared)!
        buffer.contents().copyMemory(from: bytes, byteCount: length)
        
        return MetalIndexBuffer(buffer: buffer, indexFormat: format)
    }
    
    func makeVertexBuffer(length: Int, binding: Int) -> VertexBuffer {
        let buffer = self.context.physicalDevice.makeBuffer(length: length, options: MTLResourceStorageModeShared)!
        return MetalVertexBuffer(buffer: buffer, binding: 0, offset: 0)
    }
    
    func makeBuffer(length: Int, options: ResourceOptions) -> Buffer {
        let buffer = self.context.physicalDevice.makeBuffer(length: length, options: options.metal)!
        return MetalBuffer(buffer: buffer)
    }
    
    func makeBuffer(bytes: UnsafeRawPointer, length: Int, options: ResourceOptions) -> Buffer {
        let buffer = self.context.physicalDevice.makeBuffer(bytes: bytes, length: length, options: options.metal)!
        return MetalBuffer(buffer: buffer)
    }
}

// MARK: Texture

extension MetalRenderBackend {
    func makeTexture(from descriptor: TextureDescriptor) -> GPUTexture {
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
        
        var mtlUsage: MTLTextureUsage = 0
        
        if descriptor.textureUsage.contains(.read) {
            mtlUsage |= MTLTextureUsageShaderRead
        }
        
        if descriptor.textureUsage.contains(.write) {
            mtlUsage |= MTLTextureUsageShaderWrite
        }
        
        if descriptor.textureUsage.contains(.renderTarget) {
            mtlUsage |= MTLTextureUsageRenderTarget
        }
        
        textureDesc.usage = mtlUsage
        textureDesc.width = descriptor.width
        textureDesc.height = descriptor.height
        textureDesc.pixelFormat = descriptor.pixelFormat.toMetal
        
        guard let texture = self.context.physicalDevice.makeTexture(descriptor: textureDesc) else {
            fatalError("Cannot create texture")
        }
        
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

extension MetalRenderBackend {
    
    func beginDraw(for window: Window.ID, clearColor: Color) -> DrawList {
        guard let window = self.context.windows[window] else {
            fatalError("Render Window not exists.")
        }
        
        let mtlRenderPass = window.getRenderPass()
        mtlRenderPass.colorAttachments[0].clearColor = clearColor.toMetalClearColor
        
        guard let mtlCommandBuffer = window.commandQueue.makeCommandBuffer() else {
            fatalError("Command Buffer not exists")
        }
        
        let encoder = mtlCommandBuffer.makeRenderCommandEncoder(descriptor: mtlRenderPass)!
        let commandBuffer = MetalRenderCommandBuffer(
            encoder: encoder,
            commandBuffer: mtlCommandBuffer
        )
        
        return DrawList(commandBuffer: commandBuffer)
    }
    
    func beginDraw(to framebuffer: Framebuffer, clearColors: [Color]?) -> DrawList {
        guard let mtlCommandBuffer = self.commandQueue.makeCommandBuffer() else {
            fatalError("Cannot get a command buffer")
        }
        
        guard let mtlRenderPassDesc = (framebuffer as? MetalFramebuffer)?.renderPassDescriptor else {
            fatalError("Cannot get a render pass descriptor for current draw")
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
        
        return DrawList(commandBuffer: commandBuffer)
    }
    
    // MARK: - Uniforms -
    
    func makeUniformBufferSet() -> UniformBufferSet {
        return MetalUniformBufferSet(frames: RenderEngine.configurations.maxFramesInFlight, device: self)
    }
    
    func makeUniformBuffer(length: Int, binding: Int) -> UniformBuffer {
        let buffer = self.context.physicalDevice.makeBuffer(
            length: length,
            options: MTLResourceStorageModeShared
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

// MARK: - Data

extension IndexPrimitive {
    @inlinable
    @inline(__always)
    var toMetal: MTLPrimitiveType {
        switch self {
        case .line:
            return MTLPrimitiveType.line
        case .lineStrip:
            return MTLPrimitiveType.lineStrip
        case .points:
            return MTLPrimitiveType.point
        case .triangle:
            return MTLPrimitiveType.triangle
        case .triangleStrip:
            return MTLPrimitiveType.triangleStrip
        }
    }
}

extension MetalRenderBackend {
    
    struct InternalBuffer {
        var buffer: MTLBuffer
        var offset: Int
        var index: Int
        
        /// Only for index buffer
        var indexFormat: IndexBufferFormat?
    }
    
    struct PipelineState {
        var state: MTLRenderPipelineState?
    }
}

extension PixelFormat {
    var toMetal: MTLPixelFormat {
        switch self {
        case .depth_32f_stencil8:
            return .depth32Float_stencil8
        case .depth_32f:
            return .depth32Float
        case .depth24_stencil8:
            return .depth24Unorm_stencil8
        case .bgra8:
            return .bgra8Unorm
        case .bgra8_srgb:
            return .bgra8Unorm_srgb
        case .rgba8:
            return .rgba8Unorm
        case .rgba_16f:
            return .rgba16Float
        case .rgba_32f:
            return .rgba32Float
        case .none:
            return .invalid
        }
    }
}

extension BlendOperation {
    var toMetal: MTLBlendOperation {
        switch self {
        case .add:
            return .add
        case .subtract:
            return .subtract
        case .reverseSubtract:
            return .reverseSubtract
        case .min:
            return .min
        case .max:
            return .max
        }
    }
}

extension BlendFactor {
    var toMetal: MTLBlendFactor {
        switch self {
        case .zero:
            return .zero
        case .one:
            return .one
        case .sourceColor:
            return .sourceColor
        case .oneMinusSourceColor:
            return .oneMinusSourceColor
        case .destinationColor:
            return .destinationColor
        case .oneMinusDestinationColor:
            return .oneMinusDestinationColor
        case .sourceAlpha:
            return .sourceAlpha
        case .oneMinusSourceAlpha:
            return .oneMinusSourceAlpha
        case .destinationAlpha:
            return .destinationAlpha
        case .oneMinusDestinationAlpha:
            return .oneMinusDestinationAlpha
        case .sourceAlphaSaturated:
            return .sourceAlphaSaturated
        case .blendColor:
            return .blendColor
        case .oneMinusBlendColor:
            return .oneMinusBlendColor
        case .blendAlpha:
            return .blendAlpha
        case .oneMinusBlendAlpha:
            return .oneMinusBlendAlpha
        }
    }
}

extension CompareOperation {
    var toMetal: MTLCompareFunction {
        switch self {
        case .never:
            return .never
        case .less:
            return .less
        case .equal:
            return .equal
        case .lessOrEqual:
            return .lessEqual
        case .greater:
            return .greater
        case .notEqual:
            return .notEqual
        case .greaterOrEqual:
            return .greaterEqual
        case .always:
            return .always
        }
    }
}

extension AttachmentLoadAction {
    var toMetal: MTLLoadAction {
        switch self {
        case .clear:
            return .clear
        case .dontCare:
            return .dontCare
        case .load:
            return .load
        }
    }
}

extension AttachmentStoreAction {
    var toMetal: MTLStoreAction {
        switch self {
        case .dontCare:
            return .dontCare
        case .store:
            return .store
        }
    }
}

extension Color {
    var toMetalClearColor: MTLClearColor {
        MTLClearColor(red: Double(self.red), green: Double(self.green), blue: Double(self.blue), alpha: Double(self.alpha))
    }
}

extension StencilOperation {
    var toMetal: MTLStencilOperation {
        switch self {
        case .zero:
            return .zero
        case .keep:
            return .keep
        case .replace:
            return .replace
        case .incrementAndClamp:
            return .incrementClamp
        case .decrementAndClamp:
            return .decrementClamp
        case .invert:
            return .invert
        case .incrementAndWrap:
            return .incrementWrap
        case .decrementAndWrap:
            return .decrementWrap
        }
    }
}

extension SamplerMigMagFilter {
    var toMetal: MTLSamplerMinMagFilter {
        switch self {
        case .nearest:
            return .nearest
        case .linear:
            return .linear
        }
    }
}

class MetalCommandBuffer: CommandBuffer {
    
    let commandBuffer: MTLCommandBuffer
    
    init(commandBuffer: MTLCommandBuffer) {
        self.commandBuffer = commandBuffer
    }
}

public protocol DrawCommandBuffer {
    
}

class MetalRenderCommandBuffer: DrawCommandBuffer {
    let encoder: MTLRenderCommandEncoder
    let commandBuffer: MTLCommandBuffer
    
    init(encoder: MTLRenderCommandEncoder, commandBuffer: MTLCommandBuffer) {
        self.encoder = encoder
        self.commandBuffer = commandBuffer
    }
}

// That's hack to support StorageSharedMode for swift interop
let MTLResourceStorageModeShared = Int(MTLStorageMode(rawValue: 0)!.rawValue << UInt(MTLResourceStorageModeShift))

#endif

// FIXME: (Vlad) Think about it

public extension Bundle {
    static var engineBundle: Bundle {
#if SWIFT_PACKAGE
        return Bundle.module
#else
        return Bundle(for: BundleToken.self)
#endif
    }
}

#if !SWIFT_PACKAGE
class BundleToken {}
#endif

public protocol CommandBuffer {
    
}
