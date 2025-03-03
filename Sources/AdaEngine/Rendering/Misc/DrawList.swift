//
//  DrawList.swift
//  AdaEngine
//
//  Created by v.prusakov on 1/29/23.
//

// TODO: Looks like we should use buffer binding instead of `append` methods

/// Contains information about draw. You can configure your draw whatever you want.
public final class DrawList: Sendable {
    
    public enum ShaderFunction {
        case vertex
        case fragment
    }
    
    struct BufferData<T> {
        let buffer: T
        let shaderStage: ShaderStage
    }
    
    let commandBuffer: DrawCommandBuffer
    
    static let maximumUniformsCount = 16
    static let maximumTexturesCount = 16
    
    public private(set) var renderPipeline: RenderPipeline?
    private(set) var indexBuffer: IndexBuffer?
    private(set) var lineWidth: Float?
    
    private(set) var vertexBuffers: [VertexBuffer] = []
    private(set) var uniformBuffers: [BufferData<UniformBuffer>?] = [BufferData<UniformBuffer>?].init(repeating: nil, count: maximumUniformsCount)
    private(set) var uniformBufferCount: Int = 0
    private(set) var textures: [Texture?] = [Texture?].init(repeating: nil, count: maximumTexturesCount)
    private(set) var triangleFillMode: TriangleFillMode = .fill
    private(set) var indexPrimitive: IndexPrimitive = .triangle
    private(set) var isScissorEnabled: Bool = false
    private(set) var scissorRect: Rect = .zero
    private(set) var viewport: Viewport = Viewport()
    private(set) var isViewportEnabled: Bool = false
    
    var debugName: String? {
        return debugNames.last
    }
    
    private var debugNames: [String] = []
    let renderDevice: RenderDevice

    init(commandBuffer: DrawCommandBuffer, renderDevice: RenderDevice) {
        self.commandBuffer = commandBuffer
        self.renderDevice = renderDevice
    }
    
    public func pushDebugName(_ name: String) {
        self.debugNames.append(name)
    }
    
    public func popDebugName() {
        self.debugNames.removeLast()
    }
    
    public func bindRenderPipeline(_ renderPipeline: RenderPipeline) {
        self.renderPipeline = renderPipeline
    }
    
    public func bindIndexBuffer(_ indexBuffer: IndexBuffer) {
        self.indexBuffer = indexBuffer
    }
    
    public func appendVertexBuffer(_ vertexBuffer: VertexBuffer) {
        self.vertexBuffers.append(vertexBuffer)
    }
    
    public func setLineWidth(_ lineWidth: Float?) {
        self.lineWidth = lineWidth
    }
    
    public func bindTexture(_ texture: Texture, at index: Int) {
        self.textures[index] = texture
    }
    
    public func appendUniformBuffer(_ uniformBuffer: UniformBuffer, for shaderStage: ShaderStage = .vertex) {
        self.uniformBuffers[self.uniformBufferCount] = BufferData(buffer: uniformBuffer, shaderStage: shaderStage)
        self.uniformBufferCount += 1
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
    
    public func setViewport(_ viewport: Viewport) {
        self.viewport = viewport
    }
    
    public func setViewportEnabled(_ isEnabled: Bool) {
        self.isViewportEnabled = isEnabled
    }
    
    public func clear() {
        self.renderPipeline = nil
        self.indexBuffer = nil
        self.lineWidth = nil
        
        self.vertexBuffers = []
        self.uniformBuffers = [BufferData<UniformBuffer>?].init(repeating: nil, count: Self.maximumUniformsCount)
        self.uniformBufferCount = 0
        self.textures = [Texture?].init(repeating: nil, count: Self.maximumTexturesCount)
        self.triangleFillMode = .fill
        self.indexPrimitive = .triangle
        self.scissorRect = .zero
        self.viewport = Viewport()
        self.debugNames.removeAll()
        self.isScissorEnabled = false
        self.isViewportEnabled = false
    }
    
    public func drawIndexed(
        indexCount: Int,
        indexBufferOffset: Int = 0,
        instanceCount: Int
    ) {
        renderDevice.draw(
            self,
            indexCount: indexCount,
            indexBufferOffset: indexBufferOffset,
            instanceCount: instanceCount
        )
    }
}
