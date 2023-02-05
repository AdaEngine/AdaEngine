//
//  RenderBackend.swift
//  
//
//  Created by v.prusakov on 10/9/21.
//

public enum TriangleFillMode {
    case fill
    case lines
}

protocol RenderBackend: AnyObject {
    
    var currentFrameIndex: Int { get }
    
    func createWindow(_ windowId: Window.ID, for view: RenderView, size: Size) throws
    func resizeWindow(_ windowId: Window.ID, newSize: Size) throws
    func destroyWindow(_ windowId: Window.ID) throws
    
//    func sync() throws
    
    /// Begin rendering a frame.
    func beginFrame() throws
    
    /// Release any data associated with the current frame.
    func endFrame() throws
    
    // MARK: - Buffers
    
    func makeBuffer(length: Int, options: ResourceOptions) -> Buffer
    
    func makeBuffer(bytes: UnsafeRawPointer, length: Int, options: ResourceOptions) -> Buffer
    
    func makeIndexArray(indexBuffer: IndexBuffer, indexOffset: Int, indexCount: Int) -> RID
    
    func makeIndexBuffer(index: Int, format: IndexBufferFormat, bytes: UnsafeRawPointer, length: Int) -> IndexBuffer
    
    func makeVertexBuffer(length: Int, binding: Int) -> VertexBuffer
    
    // MARK: - Shaders
    
    /// Create shader from descriptor.
    func makeShader(from descriptor: ShaderDescriptor) -> Shader
    
    /// Create a framebuffer from descriptor.
    func makeFramebuffer(from descriptor: FramebufferDescriptor) -> Framebuffer
    
    /// Create pipeline state from shader.
    func makeRenderPipeline(from descriptor: RenderPipelineDescriptor) -> RenderPipeline
    
    func makeSampler(from descriptor: SamplerDescriptor) -> Sampler
    
    // MARK: - Uniforms
    
    func makeUniformBuffer(length: Int, binding: Int) -> UniformBuffer
    
    func makeUniformBufferSet() -> UniformBufferSet
    
    // MARK: - Texture
    
    func makeTexture(from descriptor: TextureDescriptor) -> GPUTexture
    
    func getImage(for texture2D: RID) -> Image?
    
    // MARK: - Draw
    
    func beginDraw(for window: Window.ID, clearColor: Color) -> DrawList
    
    func beginDraw(to framebuffer: Framebuffer, clearColors: [Color]?) -> DrawList
    
    func draw(_ list: DrawList, indexCount: Int, instancesCount: Int)
    
    func endDrawList(_ drawList: DrawList)
}
