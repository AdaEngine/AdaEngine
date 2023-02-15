//
//  DrawList.swift
//  AdaEngine
//
//  Created by v.prusakov on 1/29/23.
//

/// Contains information about draw. You can configure your draw whatever you want.
public final class DrawList {
    
    public enum ShaderFunction {
        case vertex
        case fragment
    }
    
    struct BufferData<T> {
        let buffer: T
        let function: ShaderFunction
    }
    
    let renderPass: RenderPass
    let commandBuffer: DrawCommandBuffer
    
    static let maximumUniformsCount = 16
    static let maximumTexturesCount = 32
    
    public private(set) var renderPipeline: RenderPipeline?
    private(set) var indexArray: RID?
    private(set) var debugName: String?
    private(set) var lineWidth: Float?
    
    private(set) var vertexBuffers: [VertexBuffer] = []
    private(set) var uniformBuffers: [BufferData<UniformBuffer>?] = [BufferData<UniformBuffer>?].init(repeating: nil, count: maximumUniformsCount)
    private(set) var uniformBufferCount: Int = 0
    private(set) var textures: [Texture?] = [Texture?].init(repeating: nil, count: maximumTexturesCount)
    private(set) var renderPipline: RenderPipeline?
    private(set) var triangleFillMode: TriangleFillMode = .fill
    private(set) var indexPrimitive: IndexPrimitive = .triangle
    private(set) var isScissorEnabled: Bool = false
    private(set) var scissorRect: Rect = .zero
    private(set) var viewportRect: Rect = .zero
    private(set) var isViewportEnabled: Bool = false
    
    init(renderPass: RenderPass, commandBuffer: DrawCommandBuffer) {
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
    
    public func appendVertexBuffer(_ vertexBuffer: VertexBuffer) {
        self.vertexBuffers.append(vertexBuffer)
    }
    
    public func setLineWidth(_ lineWidth: Float?) {
        self.lineWidth = lineWidth
    }
    
    public func bindTexture(_ texture: Texture, at index: Int) {
        self.textures[index] = texture
    }
    
    public func appendUniformBuffer(_ uniformBuffer: UniformBuffer, for shaderFunction: ShaderFunction = .vertex) {
        self.uniformBuffers[self.uniformBufferCount] = BufferData(buffer: uniformBuffer, function: shaderFunction)
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
        
        self.vertexBuffers = []
        self.uniformBuffers = [BufferData<UniformBuffer>?].init(repeating: nil, count: Self.maximumUniformsCount)
        self.uniformBufferCount = 0
        self.textures = [Texture?].init(repeating: nil, count: Self.maximumTexturesCount)
        self.triangleFillMode = .fill
        self.indexPrimitive = .triangle
        self.scissorRect = .zero
        self.viewportRect = .zero
        self.isScissorEnabled = false
        self.isViewportEnabled = false
    }
}