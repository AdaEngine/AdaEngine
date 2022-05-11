//
//  MetalRenderBackend.swift
//  
//
//  Created by v.prusakov on 10/20/21.
//

#if canImport(Metal)
import Metal
import ModelIO
import MetalKit
import OrderedCollections

enum BufferIndex {
    static let uniform = 1
    static let material = 2
}

class MetalRenderBackend: RenderBackend {
    
    let context: Context
    var currentFrameIndex: Int = 0
    var currentBuffers: [MTLCommandBuffer] = []
    var maxFramesInFlight = 3
    
    var resourceMap: ResourceHashMap<MTLResource> = [:]
    var vertexBuffers: ResourceHashMap<Buffer> = [:]
    var indexBuffers: ResourceHashMap<Buffer> = [:]
    var uniformSet: ResourceHashMap<Uniform> = [:]
    
    var renderPipelineStateMap: ResourceHashMap<MTLRenderPipelineState> = [:]
    
    var inFlightSemaphore: DispatchSemaphore!
    
    private var drawableList: DrawableList?
    private var cameraData: CameraData?
    
    init(appName: String) {
        self.context = Context()
    }
    
    var viewportSize: Size {
        let viewport = self.context.viewport
        return Size(width: Float(viewport.width), height: Float(viewport.height))
    }
    
    func createWindow(for view: RenderView, size: Size) throws {
        let mtlView = (view as! MetalView)
        try self.context.createWindow(for: mtlView)
        
        self.inFlightSemaphore = DispatchSemaphore(value: self.maxFramesInFlight)
        
        for _ in 0..<maxFramesInFlight {
            let cmdBuffer = self.context.commandQueue.makeCommandBuffer()!
            self.currentBuffers.append(cmdBuffer)
        }
    }
    
    func resizeWindow(newSize: Size) throws {
        self.context.windowUpdateSize(newSize)
    }
    
    var currentBuffer: MTLCommandBuffer!
    
    func beginFrame() throws {
        self.inFlightSemaphore.wait()
        self.currentBuffer = self.context.commandQueue.makeCommandBuffer()
    }
    
    func endFrame() throws {
//        self.inFlightSemaphore.wait()
//        self.currentFrameIndex = (currentFrameIndex + 1) % maxFramesInFlight
//        let currentBuffer = self.currentBuffers[self.currentFrameIndex]
        
        
        guard let currentDrawable = self.context.view.currentDrawable else {
            return
        }
        
        currentBuffer.present(currentDrawable)
        
        currentBuffer.addCompletedHandler { _ in
            self.inFlightSemaphore.signal()
        }
        
        currentBuffer.commit()
    }
    
    func sync() {
        
    }
    
    func setClearColor(_ color: Color) {
        self.context.view.clearColor = MTLClearColor(red: Double(color.red), green: Double(color.green), blue: Double(color.blue), alpha: Double(color.alpha))
    }
    
    // MARK: - Drawable
    
    func renderDrawableList(_ list: DrawableList, camera: CameraData) {
        self.drawableList = list
        self.cameraData = camera
    }
    
    func makePipelineDescriptor(for material: Material, vertexDescriptor: MeshVertexDescriptor?) -> RID {
        do {
            let defaultLibrary = try self.context.device.makeDefaultLibrary(bundle: .module)
            let vertexFunc = defaultLibrary.makeFunction(name: "vertex_main")
            let fragmentFunc = defaultLibrary.makeFunction(name: "fragment_main")
            
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunc
            pipelineDescriptor.fragmentFunction = fragmentFunc
            pipelineDescriptor.vertexDescriptor = try vertexDescriptor?.makeMTKVertexDescriptor()
            pipelineDescriptor.colorAttachments[0].pixelFormat = self.context.view.colorPixelFormat
            
            let state = try self.context.device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            return self.renderPipelineStateMap.setValue(state)
        } catch {
            fatalError(error.localizedDescription)
        }
    }
    
    var shaders: ResourceHashMap<Shader> = [:]
    
    struct Shader {
        let binary: MTLLibrary
        let vertexFunction: MTLFunction
        let fragmentFunction: MTLFunction
        
        var vertexDescriptor: MTLVertexDescriptor = MTLVertexDescriptor()
    }
    
    func makeShader(_ shaderName: String, vertexFuncName: String, fragmentFuncName: String) -> RID {
        do {
            let url = Bundle.module.url(forResource: shaderName, withExtension: "metallib")!
            let library = try self.context.device.makeLibrary(URL: url)
            let vertexFunc = library.makeFunction(name: vertexFuncName)!
            let fragmentFunc = library.makeFunction(name: fragmentFuncName)!
            
            return self.shaders.setValue(
                Shader(
                    binary: library,
                    vertexFunction: vertexFunc,
                    fragmentFunction: fragmentFunc
                )
            )
        } catch {
            fatalError(error.localizedDescription)
        }
    }
    
    func bindAttributes(attributes: VertexDesciptorAttributesArray, forShader rid: RID) {
        guard let shader = self.shaders[rid] else {
            return
        }
        
        for (index, attribute) in attributes.enumerated() {
            shader.vertexDescriptor.attributes[index].offset = attribute.offset
            shader.vertexDescriptor.attributes[index].bufferIndex = attribute.bufferIndex
            shader.vertexDescriptor.attributes[index].format = attribute.format.metalFormat
        }
    }
    
    func bindLayouts(layouts: VertexDesciptorLayoutsArray, forShader rid: RID) {
        guard let shader = self.shaders[rid] else {
            return
        }
        
        for (index, layout) in layouts.enumerated() {
            shader.vertexDescriptor.layouts[index].stride = layout.stride
        }
    }
    
    func makePipelineState(for shader: RID) -> RID {
        guard let shader = self.shaders[shader] else {
            fatalError("Shader not found")
        }
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = shader.vertexFunction
        pipelineDescriptor.fragmentFunction = shader.fragmentFunction
        pipelineDescriptor.vertexDescriptor = shader.vertexDescriptor
        pipelineDescriptor.colorAttachments[0].pixelFormat = self.context.view.colorPixelFormat

        do {
            let state = try self.context.device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            return self.renderPipelineStateMap.setValue(state)
        } catch {
            fatalError(error.localizedDescription)
        }
        
    }
    
    // MARK: - Buffers
    
    func makeIndexBuffer(offset: Int, index: Int, bytes: UnsafeRawPointer?, length: Int) -> RID {
        let buffer = self.context.device.makeBuffer(length: length, options: .storageModeShared)!
        
        if let bytes = bytes {
            buffer.contents().copyMemory(from: bytes, byteCount: length)
        }
        
        let indexBuffer = Buffer(buffer: buffer, offset: offset, index: index)
        return self.indexBuffers.setValue(indexBuffer)
    }
    
    func makeVertexBuffer(offset: Int, index: Int, bytes: UnsafeRawPointer?, length: Int) -> RID {
        let buffer = self.context.device.makeBuffer(length: length, options: .storageModeShared)!
        
        if let bytes = bytes {
            buffer.contents().copyMemory(from: bytes, byteCount: length)
        }
        
        let indexBuffer = Buffer(buffer: buffer, offset: offset, index: index)
        return self.vertexBuffers.setValue(indexBuffer)
    }
    
    func setVertexBufferData(_ vertexBuffer: RID, bytes: UnsafeRawPointer, length: Int) {
        guard let buffer = self.vertexBuffers[vertexBuffer] else {
            assertionFailure("Vertex buffer not found")
            return
        }
        
        buffer.buffer.contents().copyMemory(from: bytes, byteCount: length)
    }
    
    func setIndexBufferData(_ indexBuffer: RID, bytes: UnsafeRawPointer, length: Int) {
        guard let buffer = self.indexBuffers[indexBuffer] else {
            assertionFailure("Vertex buffer not found")
            return
        }
        
        buffer.buffer.contents().copyMemory(from: bytes, byteCount: length)
    }
    
    func makeBuffer(length: Int, options: ResourceOptions) -> RID {
        let buffer = self.context.device.makeBuffer(length: length, options: options.metal)!
        return self.resourceMap.setValue(buffer)
    }
    
    func makeBuffer(bytes: UnsafeRawPointer, length: Int, options: ResourceOptions) -> RID {
        let buffer = self.context.device.makeBuffer(bytes: bytes, length: length, options: options.metal)!
        return self.resourceMap.setValue(buffer)
    }
    
    func getBuffer(for rid: RID) -> RenderBuffer {
        guard let buffer = self.resourceMap.get(rid) as? MTLBuffer else {
            fatalError("Can't find buffer for rid \(rid)")
        }
        
        return MetalBuffer(buffer)
    }
    
    var drawList: ResourceHashMap<Draw> = [:]
}

extension MetalRenderBackend {
    
    struct Draw {
        var debugName: String?
        let commandBuffer: MTLCommandBuffer
        let renderPassDescriptor: MTLRenderPassDescriptor
        var vertexBuffer: RID? = nil
        var indexBuffer: RID? = nil
        var uniformSet: RID? = nil
        var renderState: MTLRenderPipelineState? = nil
        var lineWidth: Float?
    }
    
    struct Buffer {
        var buffer: MTLBuffer
        var offset: Int
        var index: Int
    }
    
    struct Uniform {
        var buffer: MTLBuffer
        var offset: Int
        var index: Int
    }
    
    func beginDrawList() -> RID {
        
        guard let renderPass = self.context.view.currentRenderPassDescriptor else {
            fatalError("Can't get render pass descriptor")
        }
        
        let draw = Draw(
            commandBuffer: self.currentBuffer,//self.currentBuffers[self.currentFrameIndex],
            renderPassDescriptor: renderPass
        )
        return self.drawList.setValue(draw)
    }
    
    func bindDebugName(name: String, forDraw drawId: RID) {
        self.drawList[drawId]?.debugName = name
    }
    
    func bindLineWidth(_ width: Float, forDraw drawId: RID) {
        self.drawList[drawId]?.lineWidth = width
    }
    
    func bindRenderState(_ drawRid: RID, renderPassId: RID) {
        var draw = self.drawList[drawRid]
        assert(draw != nil, "Draw is not exists")
        
        let renderState = self.renderPipelineStateMap[renderPassId]
        draw?.renderState = renderState
        
        self.drawList[drawRid] = draw
    }
    
    func bindUniformSet(_ drawRid: RID, uniformSet: RID) {
        var draw = self.drawList[drawRid]
        assert(draw != nil, "Draw is not exists")
        draw?.uniformSet = uniformSet
        self.drawList[drawRid] = draw
    }
    
    func bindVertexBuffer(_ drawRid: RID, vertexBuffer: RID) {
        var draw = self.drawList[drawRid]
        assert(draw != nil, "Draw is not exists")
        draw?.vertexBuffer = vertexBuffer
        self.drawList[drawRid] = draw
    }
    
    func bindIndexBuffer(_ drawRid: RID, indexBuffer: RID) {
        var draw = self.drawList[drawRid]
        assert(draw != nil, "Draw is not exists")
        draw?.indexBuffer = indexBuffer
        self.drawList[drawRid] = draw
    }
    
    func makeUniform<T>(_ uniformType: T.Type, count: Int, index: Int, offset: Int, options: ResourceOptions) -> RID {
        let buffer = self.context.device.makeBuffer(
            length: MemoryLayout<T>.size * count,
            options: options.metal
        )!
        
        let uniform = Uniform(
            buffer: buffer,
            offset: offset,
            index: index
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
    
    func createTexture(size: Vector2i?) -> RID {
        let descriptor = MTLTextureDescriptor()
        descriptor.textureType = .type2D
        descriptor.height = size?.y ?? 1
        descriptor.width = size?.x ?? 1
        guard let texture = self.context.device.makeTexture(descriptor: descriptor) else {
            fatalError()
        }
        return self.resourceMap.setValue(texture)
    }
    
    func draw(_ drawRid: RID, indexCount: Int, instancesCount: Int) {
        guard let draw = self.drawList[drawRid] else {
            fatalError("Draw list not found")
        }
        
        guard let encoder = draw.commandBuffer.makeRenderCommandEncoder(descriptor: draw.renderPassDescriptor) else {
            assertionFailure("Can't create render command encoder")
            return
        }
        
        if let name = draw.debugName {
            draw.commandBuffer.pushDebugGroup(name)
        }
        
        if let renderState = draw.renderState {
            encoder.setRenderPipelineState(renderState)
        }
        
        guard let ibRid = draw.indexBuffer, let indexBuffer = self.indexBuffers[ibRid] else {
            fatalError("can't draw without index buffer")
        }
        
        if let vbRid = draw.vertexBuffer, let vertexBuffer = self.vertexBuffers[vbRid] {
            encoder.setVertexBuffer(vertexBuffer.buffer, offset: vertexBuffer.offset, index: vertexBuffer.index)
        }
        
        if let usId = draw.uniformSet, let uniformSet = self.uniformSet[usId] {
            encoder.setVertexBuffer(uniformSet.buffer, offset: uniformSet.offset, index: uniformSet.index)
        }
        
        encoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: indexCount,
            indexType: .uint32,
            indexBuffer: indexBuffer.buffer,
            indexBufferOffset: indexBuffer.offset,
            instanceCount: instancesCount
        )
        
        encoder.endEncoding()
        
        if let _ = draw.debugName {
            draw.commandBuffer.popDebugGroup()
        }
    }
    
    func drawEnd(_ drawId: RID) {
        self.drawList[drawId] = nil
    }
    
//    func drawDrawable(
//        _ drawable: Drawable,
//        commandBuffer: MTLCommandBuffer,
//        descriptor: MTLRenderPassDescriptor,
//        uniform: Uniforms
//    ) throws {
//        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
//
//        defer {
//            encoder?.endEncoding()
//        }
//
//        var uniform = uniform
//
//        guard
//            let rid = drawable.pipelineState,
//            let pipelineState = self.renderPipelineStateMap.get(rid)
//        else { return }
//
//        switch drawable.source {
//        case .mesh(let mesh):
//
//            encoder?.setRenderPipelineState(pipelineState)
//
//            uniform.modelMatrix = drawable.transform
//
//            for model in mesh.models {
//                encoder?.setVertexBuffer(model.vertexBuffer.get(), offset: 0, index: 0)
//                encoder?.setVertexBytes(&uniform, length: MemoryLayout<Uniforms>.stride, index: BufferIndex.uniform)
//
//                for surface in model.surfaces {
//                    // FIXME: Remove it later
//                    if var material = (drawable.materials?[surface.materialIndex] as? BaseMaterial)?.diffuseColor {
//                        encoder?.setVertexBytes(&material, length: MemoryLayout.size(ofValue: material), index: BufferIndex.material)
//                    }
//
//                    encoder?.drawIndexedPrimitives(
//                        type: surface.primitiveType.metal,
//                        indexCount: surface.indexCount,
//                        indexType: surface.isUInt32 ? .uint32 : .uint16,
//                        indexBuffer: surface.indexBuffer.get()!,
//                        indexBufferOffset: 0
//                    )
//                }
//            }
//
//        case .light:
//            encoder?.setRenderPipelineState(pipelineState)
//            break
//        case .empty:
//            break
//        }
//    }
}

extension MetalRenderBackend {
    
    final class Context {
        
        weak var view: MetalView!
        
        var device: MTLDevice!
        var commandQueue: MTLCommandQueue!
        var viewport: MTLViewport = MTLViewport()
        var pipelineState: MTLRenderPipelineState!
        
        // MARK: - Methods
        
        func createWindow(for view: MetalView) throws {
            
            self.view = view
            
            self.viewport = MTLViewport(originX: 0, originY: 0, width: Double(view.drawableSize.width), height: Double(view.drawableSize.height), znear: 0, zfar: 1)
            
            self.device = self.prefferedDevice(for: view)
            view.device = self.device
            
            self.commandQueue = self.device.makeCommandQueue()
        }
        
        func prefferedDevice(for view: MetalView) -> MTLDevice {
            return view.preferredDevice ?? MTLCreateSystemDefaultDevice()!
        }
        
        func windowUpdateSize(_ size: Size) {
            self.viewport = MTLViewport(originX: 0, originY: 0, width: Double(size.width), height: Double(size.height), znear: 0, zfar: 1)
        }
        
    }
}

#endif

/// Resource Identifier
public struct RID: Equatable, Hashable, Codable {
    public let id: Int
}

extension RID {
    
    /// Generate random unique rid
    init() {
        self.id = Self.readTime()
    }
    
    private static func readTime() -> Int {
        var time = timespec()
        clock_gettime(CLOCK_MONOTONIC, &time)
        
        return (time.tv_sec * 10000000) + (time.tv_nsec / 100) + 0x01B21DD213814000;
    }
}

/// The data type contains any values usign RID as key
/// - Note: ResourceHashMap is thread safety
public struct ResourceHashMap<T> {
    
    private var queue: DispatchQueue = DispatchQueue(label: "ResourceMap-\(T.self)")
    
    private var dictionary: OrderedDictionary<RID, T> = [:]
    
    public func get(_ rid: RID) -> T? {
        return self.queue.sync {
            return self.dictionary[rid]
        }
    }
    
    /// Generate new RID and set value for it
    /// - Returns: RID instance of holded resource
    public mutating func setValue(_ value: T) -> RID {
        self.queue.sync(flags: .barrier) {
            let rid = RID()
            self.dictionary[rid] = value
            
            return rid
        }
    }
    
    public mutating func setValue(_ value: T?, forKey rid: RID) {
        self.queue.sync(flags: .barrier) {
            self.dictionary[rid] = value
        }
    }
    
    public mutating func removeAll() {
        self.queue.sync(flags: .barrier) {
            self.dictionary.removeAll()
        }
    }
    
    public subscript(_ rid: RID) -> T? {
        get {
            return self.get(rid)
        }
        
        set {
            self.setValue(newValue, forKey: rid)
        }
    }
}

extension ResourceHashMap: Sequence {
    public typealias Iterator = OrderedDictionary<RID, T>.Iterator
    
    public func makeIterator() -> OrderedDictionary<RID, T>.Iterator {
        return self.dictionary.makeIterator()
    }
}

extension ResourceHashMap: ExpressibleByDictionaryLiteral {
    
    public init(dictionaryLiteral elements: (RID, T)...) {
        self.dictionary.merge(elements, uniquingKeysWith: { $1 })
    }
}

// TODO: Move to utils folder
public func mem_size<T>(of object: T) -> Int {
    return MemoryLayout.size(ofValue: object)
}

public func mem_size<T>(_ object: T.Type) -> Int {
    return MemoryLayout<T>.size
}
