//
//  MetalRenderBackend.swift
//  
//
//  Created by v.prusakov on 10/20/21.
//

enum BufferIndex {
    static let baseUniform = 1
    static let material = 2
}

// TODO: (Vlad) We should support bgra8Unorm_srgb

#if METAL
import Metal
import ModelIO
import MetalKit
import OrderedCollections

class MetalRenderBackend: RenderBackend {
    
    private let context: Context
    private(set) var currentFrameIndex: Int = 0
    private var maxFramesInFlight = 3
    
    private var resourceMap: ResourceHashMap<MTLResource> = [:]
    private var vertexBuffers: ResourceHashMap<InternalBuffer> = [:]
    private var uniformSet: ResourceHashMap<Uniform> = [:]
    
    private var indexArrays: ResourceHashMap<IndexArray> = [:]
    private var vertexArrays: ResourceHashMap<VertexArray> = [:]
    
    private var textures: ResourceHashMap<GPUTexture> = [:]
    
    private var renderPipelineStateMap: ResourceHashMap<PipelineState> = [:]
    
    private var inFlightSemaphore: DispatchSemaphore
    
    init(appName: String) {
        self.context = Context()
        
        self.inFlightSemaphore = DispatchSemaphore(value: self.maxFramesInFlight)
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
            window.commandBuffer = window.commandQueue.makeCommandBuffer()
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
        
        currentFrameIndex = (currentFrameIndex + 1) % maxFramesInFlight
    }
    
    func makeShader(from descriptor: ShaderDescriptor) -> Shader {
        do {
            let library: MTLLibrary
            
            #if (os(macOS) || os(iOS)) && TUIST
            library = try self.context.physicalDevice.makeDefaultLibrary(bundle: .current)
            #else
            
            let url = Bundle.current.url(forResource: descriptor.shaderName, withExtension: "metal", subdirectory: "Metal")!
            let source = try String(contentsOf: url)

            library = try self.context.physicalDevice.makeLibrary(source: source, options: nil)
            #endif
            
            let vertexFunc = library.makeFunction(name: descriptor.vertexFunction)!
            let fragmentFunc = library.makeFunction(name: descriptor.fragmentFunction)!
            
            return MetalShader(
                name: descriptor.shaderName,
                library: library,
                vertexFunction: vertexFunc,
                fragmentFunction: fragmentFunc
            )
        } catch {
            fatalError(error.localizedDescription)
        }
    }
    
//    func makeFramebuffer(from descriptor: FramebufferDescriptor) -> Framebuffer {
//        return MetalFramebuffer(
//            viewport: <#T##MTLViewport#>,
//            descriptor: descriptor,
//            renderPass: <#T##RenderPass#>
//        )
//    }
//
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
        
        guard let shader = descriptor.shader as? MetalShader else {
            fatalError("Incorrect type of shader")
        }
        
        pipelineDescriptor.vertexFunction = shader.vertexFunction
        pipelineDescriptor.fragmentFunction = shader.fragmentFunction
        
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
            fatalError(error.localizedDescription)
        }
    }
    
    func makeRenderPass(from descriptor: RenderPassDescriptor) -> RenderPass {
        let renderPassDescriptor = MTLRenderPassDescriptor()
        
        for (index, attachment) in descriptor.attachments.enumerated() {
            if attachment.format.isDepthFormat {
                renderPassDescriptor.depthAttachment.loadAction = descriptor.depthLoadAction.toMetal
                renderPassDescriptor.depthAttachment.clearDepth = descriptor.clearDepth
                
                if let renderTarget = attachment.texture, let texture = self.textures[renderTarget.rid] {
                    renderPassDescriptor.depthAttachment.texture = texture.resource
                    renderPassDescriptor.stencilAttachment.texture = texture.resource
                }
            } else {
                renderPassDescriptor.colorAttachments[index].slice = attachment.slice
                renderPassDescriptor.colorAttachments[index].clearColor = attachment.clearColor.toMetalClearColor
                renderPassDescriptor.colorAttachments[index].loadAction = attachment.loadAction.toMetal
                renderPassDescriptor.colorAttachments[index].storeAction = attachment.storeAction.toMetal
                
                if let renderTarget = attachment.texture, let texture = self.textures[renderTarget.rid] {
                    renderPassDescriptor.colorAttachments[index].texture = texture.resource
                }
            }
        }
        
        if descriptor.width > 0 {
            renderPassDescriptor.renderTargetWidth = Int(descriptor.width)
        }
        
        if descriptor.height > 0 {
            renderPassDescriptor.renderTargetHeight = Int(descriptor.height)
        }
        
        return MetalRenderPass(descriptor: descriptor, renderPass: renderPassDescriptor)
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
    
    func makeIndexArray(indexBuffer: IndexBuffer, indexOffset: Int, indexCount: Int) -> RID {
        let array = IndexArray(
            buffer: indexBuffer,
            offset: indexOffset,
            indices: indexCount
        )
        
        return self.indexArrays.setValue(array)
    }
    
    func makeVertexArray(vertexBuffers: [RID], vertexCount: Int) -> RID {
        let array = VertexArray(buffers: vertexBuffers, vertexCount: vertexCount)
        return self.vertexArrays.setValue(array)
    }
    
    func makeIndexBuffer(index: Int, format: IndexBufferFormat, bytes: UnsafeRawPointer, length: Int) -> IndexBuffer {
        let buffer = self.context.physicalDevice.makeBuffer(length: length, options: .storageModeShared)!
        buffer.contents().copyMemory(from: bytes, byteCount: length)
        
        return MetalIndexBuffer(buffer: buffer, indexFormat: format)
    }
    
    func makeVertexBuffer(offset: Int, index: Int, bytes: UnsafeRawPointer?, length: Int) -> RID {
        let buffer = self.context.physicalDevice.makeBuffer(length: length, options: .storageModeShared)!
        
        if let bytes = bytes {
            buffer.contents().copyMemory(from: bytes, byteCount: length)
        }
        
        let vertexBuffer = InternalBuffer(buffer: buffer, offset: offset, index: index)
        return self.vertexBuffers.setValue(vertexBuffer)
    }
    
    func setVertexBufferData(_ vertexBuffer: RID, bytes: UnsafeRawPointer, length: Int) {
        guard let buffer = self.vertexBuffers[vertexBuffer] else {
            assertionFailure("Vertex buffer not found")
            return
        }
        
        buffer.buffer.contents().copyMemory(from: bytes, byteCount: length)
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
    func makeTexture(from descriptor: TextureDescriptor) -> RID {
        let textureDesc = MTLTextureDescriptor()
        
        switch descriptor.textureType {
        case .cube:
            textureDesc.textureType = .typeCube
        case .texture2D:
            textureDesc.textureType = .type2D
        case .texture2DArray:
            textureDesc.textureType = .type2DArray
        case .texture3D:
            textureDesc.textureType = .type3D
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
        
        guard let texture = self.context.physicalDevice.makeTexture(descriptor: textureDesc) else {
            fatalError("Cannot create texture")
        }
        
        var gpuTexture = GPUTexture(resource: texture, images: [])
        
        if let image = descriptor.image {
            let region = MTLRegion(
                origin: MTLOrigin(x: 0, y: 0, z: 0),
                size: MTLSize(width: image.width, height: image.height, depth: 1)
            )
            
            let bytesPerRow = 4 * image.width
            
            image.data.withUnsafeBytes { buffer in
                precondition(buffer.baseAddress != nil, "Image should not contains empty address.")
                
                texture.replace(
                    region: region,
                    mipmapLevel: 0,
                    withBytes: buffer.baseAddress!,
                    bytesPerRow: bytesPerRow
                )
            }
            
            gpuTexture.images.append(image)
        }
        
        return self.textures.setValue(gpuTexture)
    }
    
    func removeTexture(by rid: RID) {
        self.textures[rid] = nil
    }
    
    // TODO: (Vlad) think about it later
    func getImage(for texture2D: RID) -> Image? {
        guard let texture = self.textures[texture2D] else {
            assertionFailure("Texture for given rid not exists")
            
            return nil
        }
        
        let mtlTexture = texture.resource
        
        if mtlTexture.isFramebufferOnly {
            return nil
        }
        
        let imageFormat: Image.Format
        let bytesInPixel: Int
        
        switch mtlTexture.pixelFormat {
        case .bgra8Unorm_srgb, .bgra8Unorm:
            imageFormat = .bgra8
            bytesInPixel = 4
        default:
            imageFormat = .rgba8
            bytesInPixel = 4
        }
        
        let bytesPerRow = bytesInPixel * mtlTexture.width
        
        var data = Data(capacity: mtlTexture.allocatedSize)
        data.withUnsafeMutableBytes { bufferPtr in
            mtlTexture.getBytes(
                bufferPtr.baseAddress!,
                bytesPerRow: bytesPerRow,
                from: MTLRegion(
                    origin: MTLOrigin(x: 0, y: 0, z: 0),
                    size: MTLSize(width: mtlTexture.width, height: mtlTexture.height, depth: 1)
                ),
                mipmapLevel: 0
            )
        }
        
        return Image(width: mtlTexture.width, height: mtlTexture.height, data: data, format: imageFormat)
    }
}

// MARK: - Drawings

extension MetalRenderBackend {
    
    func beginDraw(for window: Window.ID) -> DrawList {
        guard let window = self.context.windows[window] else {
            fatalError("Render Window not exists.")
        }
        
        let mtlRenderPass = window.getDrawableRenderPass()
        
        let renderPass = MetalRenderPass(
            descriptor: RenderPassDescriptor(),
            renderPass: mtlRenderPass
        )
        
        guard let mtlCommandBuffer = window.commandBuffer else {
            fatalError("Command Buffer not exists")
        }
        
        let encoder = mtlCommandBuffer.makeRenderCommandEncoder(descriptor: mtlRenderPass)!
        let commandBuffer = MetalRenderCommandBuffer(
            encoder: encoder,
            commandBuffer: mtlCommandBuffer,
            destinationTexture: window.drawable!.texture
        )
        
        return DrawList(
            renderPass: renderPass,
            commandBuffer: commandBuffer
        )
    }
    
    func beginDraw(for window: Window.ID, renderPass: RenderPass) -> DrawList {
        guard let window = self.context.windows[window] else {
            fatalError("Render Window not exists.")
        }
        
        guard let mtlCommandBuffer = window.commandBuffer else {
            fatalError("Command Buffer not exists")
        }
        
        guard let mtlRenderPassDesc = (renderPass as? MetalRenderPass)?.renderPass else {
            fatalError("Not supported render pass type")
        }
        
        let encoder = mtlCommandBuffer.makeRenderCommandEncoder(descriptor: mtlRenderPassDesc)!
        let commandBuffer = MetalRenderCommandBuffer(
            encoder: encoder,
            commandBuffer: mtlCommandBuffer,
            destinationTexture: window.drawable!.texture
        )
        
        return DrawList(
            renderPass: renderPass,
            commandBuffer: commandBuffer
        )
    }
    
    func makeUniform<T>(_ uniformType: T.Type, count: Int, offset: Int, options: ResourceOptions) -> RID {
        let buffer = self.context.physicalDevice.makeBuffer(
            length: MemoryLayout<T>.size * count,
            options: options.metal
        )!
        
        let uniform = Uniform(
            buffer: buffer,
            offset: offset
        )
        
        return self.uniformSet.setValue(uniform)
    }
    
    func updateUniform<T>(_ rid: RID, value: T, count: Int) {
        guard let uniform = self.uniformSet.get(rid) else {
            fatalError("Can't find uniform for rid \(rid)")
        }
        var temp = value
        uniform.buffer.contents().copyMemory(from: &temp, byteCount: MemoryLayout.stride(ofValue: value) * count)
    }
    
    func removeUniform(_ rid: RID) {
        self.uniformSet.setValue(nil, forKey: rid)
    }
    
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func draw(_ list: DrawList, indexCount: Int, instancesCount: Int) {
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
            let rect = list.viewportRect
            
            encoder.setViewport(
                MTLViewport(
                    originX: Double(rect.origin.x),
                    originY: Double(rect.origin.y),
                    width: Double(rect.size.width),
                    height: Double(rect.size.height),
                    znear: Double(0),
                    zfar: Double(1)
                )
            )
        }
        
        guard let iaRid = list.indexArray, let indexArray = self.indexArrays[iaRid] else {
            fatalError("can't draw without index array")
        }
        
        if let vaRid = list.vertexArray, let vertexArray = self.vertexArrays[vaRid] {
            for vertexRid in vertexArray.buffers {
                guard let vertexBuffer = self.vertexBuffers[vertexRid] else {
                    continue
                }
                
                encoder.setVertexBuffer(vertexBuffer.buffer, offset: vertexBuffer.offset, index: vertexBuffer.index)
            }
        }
        
        let textures: [MTLTexture] = list.textures.compactMap { (texture: Texture?) in
            guard let rid = texture?.rid else { return nil }
            return self.textures[rid]?.resource
        }
        
        if !textures.isEmpty {
            encoder.setFragmentTextures(textures, range: 0..<textures.count)
        }
        
        // I think it should be passed to draw list
        if let mtlSampler = (renderPipeline.descriptor.sampler as? MetalSampler)?.mtlSampler {
            encoder.setFragmentSamplerState(mtlSampler, index: 0)
        }
        
        for (index, uniRid) in list.uniformSet {
            let uniform = self.uniformSet[uniRid]!
            encoder.setVertexBuffer(uniform.buffer, offset: uniform.offset, index: index)
        }
        
        switch list.triangleFillMode {
        case .fill:
            encoder.setTriangleFillMode(.fill)
        case .lines:
            encoder.setTriangleFillMode(.lines)
        }
        
        encoder.drawIndexedPrimitives(
            type: list.indexPrimitive == .line ? .line : .triangle,
            indexCount: indexCount,
            indexType: indexArray.buffer.indexFormat == .uInt32 ? .uint32 : .uint16,
            indexBuffer: (indexArray.buffer as! MetalIndexBuffer).buffer,
            indexBufferOffset: indexArray.offset,
            instanceCount: instancesCount
        )
    }
    
    func endDrawList(_ drawList: DrawList) {
        guard let commandBuffer = drawList.commandBuffer as? MetalRenderCommandBuffer else {
            return
        }
        
        commandBuffer.encoder.endEncoding()
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
    
    struct Uniform {
        var buffer: MTLBuffer
        var offset: Int
    }
    
    struct IndexArray {
        var buffer: IndexBuffer
        var offset: Int = 0
        var indices: Int = 0
    }
    
    struct VertexArray {
        var buffers: [RID] = []
        var vertexCount: Int = 0
    }
    
    struct PipelineState {
        var state: MTLRenderPipelineState?
    }
    
    struct GPUTexture {
        let resource: MTLTexture
        var images: [Image]
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

#endif

// FIXME: (Vlad) Think about it

extension Bundle {
    static var current: Bundle {
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

public final class DrawList {
    
    public let renderPass: RenderPass
    let commandBuffer: CommandBuffer
    
    public private(set) var renderPipeline: RenderPipeline?
    private(set) var indexArray: RID?
    private(set) var debugName: String?
    private(set) var lineWidth: Float?
    
    private(set) var vertexArray: RID?
    private(set) var uniformSet: [Int: RID] = [:]
    private(set) var textures: [Texture?] = [Texture?].init(repeating: nil, count: 32)
    private(set) var renderPipline: RenderPipeline?
    private(set) var triangleFillMode: TriangleFillMode = .fill
    private(set) var indexPrimitive: IndexPrimitive = .triangle
    private(set) var isScissorEnabled: Bool = false
    private(set) var scissorRect: Rect = .zero
    private(set) var viewportRect: Rect = .zero
    private(set) var isViewportEnabled: Bool = false
    
    init(renderPass: RenderPass, commandBuffer: CommandBuffer) {
        self.renderPass = renderPass
        self.commandBuffer = commandBuffer
    }
    
    public func setDebugName(_ name: String) {
        self.debugName = name
    }
    
    public func bindRenderPipeline(_ renderPipeline: RenderPipeline) {
        self.renderPipeline = renderPipeline
    }
    
    public func bindIndexArray(_ indexArray: RID) {
        self.indexArray = indexArray
    }
    
    public func bindVertexArray(_ vertexArray: RID) {
        self.vertexArray = vertexArray
    }
    
    public func setLineWidth(_ lineWidth: Float?) {
        self.lineWidth = lineWidth
    }
    
    public func bindTexture(_ texture: Texture, at index: Int) {
        self.textures[index] = texture
    }
    
    public func bindUniformSet(_ uniformSet: RID, at index: Int) {
        self.uniformSet[index] = uniformSet
    }
    
    public func setScissorRect(_ rect: Rect) {
        self.scissorRect = rect
    }
    
    public func setScissorEnabled(_ isEnabled: Bool) {
        self.isScissorEnabled = isEnabled
    }
    
    public func bindTriangleFillMode(_ mode: TriangleFillMode) {
        self.triangleFillMode = mode
    }
    
    public func bindIndexPrimitive(_ primitive: IndexPrimitive) {
        self.indexPrimitive = primitive
    }
    
    public func setViewport(_ rect: Rect) {
        self.viewportRect = rect
    }
    
    public func setViewportEnabled(_ isEnabled: Bool) {
        self.isViewportEnabled = isEnabled
    }
    
    public func clear() {
        self.renderPipeline = nil
        self.indexArray = nil
        self.debugName = nil
        self.lineWidth = nil
        
        self.vertexArray = nil
        self.uniformSet = [:]
        self.textures.removeAll(keepingCapacity: true)
        self.triangleFillMode = .fill
        self.indexPrimitive = .triangle
        self.scissorRect = .zero
        self.viewportRect = .zero
        self.isScissorEnabled = false
        self.isViewportEnabled = false
    }
}

public protocol CommandBuffer {
    
}

class MetalCommandBuffer: CommandBuffer {
    
    let commandBuffer: MTLCommandBuffer
    
    init(commandBuffer: MTLCommandBuffer) {
        self.commandBuffer = commandBuffer
    }
}

class MetalRenderCommandBuffer: CommandBuffer {
    let encoder: MTLRenderCommandEncoder
    let commandBuffer: MTLCommandBuffer
    let destinationTexture: MTLTexture
    
    init(encoder: MTLRenderCommandEncoder, commandBuffer: MTLCommandBuffer, destinationTexture: MTLTexture) {
        self.encoder = encoder
        self.commandBuffer = commandBuffer
        self.destinationTexture = destinationTexture
    }
}
