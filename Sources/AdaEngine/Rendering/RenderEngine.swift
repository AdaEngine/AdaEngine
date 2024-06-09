//
//  RenderEngine.swift
//  AdaEngine
//
//  Created by v.prusakov on 10/25/21.
//

import OrderedCollections
import Math

public enum GlobalBufferIndex {
    public static let viewUniform: Int = 1
}

/// Render Engine is object that manage a GPU.
public final class RenderEngine: RenderBackend {
    
    public struct Configuration {
        
        public var maxFramesInFlight: Int = 3
        
        public init() {}
    }
    
    /// Setup configuration for render engine
    public static var configurations: Configuration = Configuration()
    
    /// Return instance of render engine for specific backend.
    public static let shared: RenderEngine = {
        let renderBackend: RenderBackend
        
        #if METAL
        renderBackend = MetalRenderBackend(appName: "Ada Engine")
        #elseif VULKAN
        renderBackend = VulkanRenderBackend(appName: "Ada Engine")
        #endif
        
        return RenderEngine(renderBackend: renderBackend)
    }()
    
    private let renderBackend: RenderBackend
    
    private init(renderBackend: RenderBackend) {
        self.renderBackend = renderBackend
    }
    
    // MARK: - RenderBackend
    
    public var currentFrameIndex: Int {
        return self.renderBackend.currentFrameIndex
    }
    
    public func createWindow(_ windowId: UIWindow.ID, for view: RenderView, size: SizeInt) throws {
        try self.renderBackend.createWindow(windowId, for: view, size: size)
    }
    
    public func resizeWindow(_ windowId: UIWindow.ID, newSize: SizeInt) throws {
        try self.renderBackend.resizeWindow(windowId, newSize: newSize)
    }
    
    public func destroyWindow(_ windowId: UIWindow.ID) throws {
        try self.renderBackend.destroyWindow(windowId)
    }
    
    func beginFrame() throws {
        preconditionMainThreadOnly()
        try self.renderBackend.beginFrame()
    }
    
    func endFrame() throws {
        preconditionMainThreadOnly()
        try self.renderBackend.endFrame()
    }
    
    // MARK: - Buffers -
    
    func makeBuffer(length: Int, options: ResourceOptions) -> Buffer {
        return self.renderBackend.makeBuffer(length: length, options: options)
    }
    
    func makeBuffer(bytes: UnsafeRawPointer, length: Int, options: ResourceOptions) -> Buffer {
        return self.renderBackend.makeBuffer(bytes: bytes, length: length, options: options)
    }
    
    func makeIndexBuffer(format: IndexBufferFormat, bytes: UnsafeRawPointer, length: Int) -> IndexBuffer {
        return self.renderBackend.makeIndexBuffer(format: format, bytes: bytes, length: length)
    }
    
    func makeVertexBuffer(length: Int, binding: Int) -> VertexBuffer {
        self.renderBackend.makeVertexBuffer(length: length, binding: binding)
    }
    
    // MARK: - Shaders
    
    func makeSampler(from descriptor: SamplerDescriptor) -> Sampler {
        return self.renderBackend.makeSampler(from: descriptor)
    }
    
    func makeFramebuffer(from descriptor: FramebufferDescriptor) -> Framebuffer {
        return self.renderBackend.makeFramebuffer(from: descriptor)
    }
    
    func makeRenderPipeline(from descriptor: RenderPipelineDescriptor) -> RenderPipeline {
        return self.renderBackend.makeRenderPipeline(from: descriptor)
    }
    
    func compileShader(from shader: Shader) throws -> CompiledShader {
        return try self.renderBackend.compileShader(from: shader)
    }
    
    // MARK: - Uniforms -
    
    func makeUniformBuffer(length: Int, binding: Int) -> UniformBuffer {
        self.renderBackend.makeUniformBuffer(length: length, binding: binding)
    }
    
    func makeUniformBufferSet() -> UniformBufferSet {
        self.renderBackend.makeUniformBufferSet()
    }
    
    // MARK: - Texture -
    
    func makeTexture(from descriptor: TextureDescriptor) -> GPUTexture {
        self.renderBackend.makeTexture(from: descriptor)
    }
    
    func getImage(from texture: Texture) -> Image? {
        self.renderBackend.getImage(from: texture)
    }
    
    // MARK: - Drawing -
    
    func beginDraw(for window: UIWindow.ID, clearColor: Color) -> DrawList {
        self.renderBackend.beginDraw(for: window, clearColor: clearColor)
    }
    
    func beginDraw(to framebuffer: Framebuffer, clearColors: [Color]?) -> DrawList {
        self.renderBackend.beginDraw(to: framebuffer, clearColors: clearColors)
    }
    
    func draw(_ list: DrawList, indexCount: Int, indexBufferOffset: Int, instanceCount: Int) {
        self.renderBackend.draw(
            list,
            indexCount: indexCount,
            indexBufferOffset: indexBufferOffset,
            instanceCount: instanceCount
        )
    }
    
    func endDrawList(_ drawList: DrawList) {
        self.renderBackend.endDrawList(drawList)
    }
}

public extension RenderEngine {
    func makeUniformBuffer<T>(_ uniformType: T.Type, count: Int = 1, binding: Int) -> UniformBuffer {
        self.makeUniformBuffer(length: MemoryLayout<T>.stride * count, binding: binding)
    }
}
