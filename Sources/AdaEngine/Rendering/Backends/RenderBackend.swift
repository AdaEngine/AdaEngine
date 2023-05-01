//
//  RenderBackend.swift
//  AdaEngine
//
//  Created by v.prusakov on 10/9/21.
//

public enum TriangleFillMode {
    case fill
    case lines
}

/// This protocol describe interface for GPU.
protocol RenderBackend: AnyObject {
    
    /// Returns current frame index. Min value 0, Max value is equal ``RenderEngine/Configuration/maxFramesInFlight`` value.
    var currentFrameIndex: Int { get }
    
    /// Register a new render window for render backend.
    /// Window in this case is entity that managed a drawables (aka swapchain).
    /// - Throws: Throw error if something went wrong.
    func createWindow(_ windowId: Window.ID, for view: RenderView, size: Size) throws
    
    /// Resize registred render window.
    /// - Throws: Throw error if window is not registred.
    func resizeWindow(_ windowId: Window.ID, newSize: Size) throws
    
    /// Destroy render window from render backend.
    /// - Throws: Throw error if window is not registred.
    func destroyWindow(_ windowId: Window.ID) throws
    
    /// Begin rendering a frame for all windows.
    func beginFrame() throws
    
    /// Release any data associated with the current frame.
    func endFrame() throws
    
    // MARK: - Buffers
    
    /// Create a new GPU buffer with specific length and options.
    func makeBuffer(length: Int, options: ResourceOptions) -> Buffer
    
    /// Create a new GPU buffer with specific data, length and options.
    func makeBuffer(bytes: UnsafeRawPointer, length: Int, options: ResourceOptions) -> Buffer
    
    /// Create a new index buffer with specific index, format, data and length.
    func makeIndexBuffer(format: IndexBufferFormat, bytes: UnsafeRawPointer, length: Int) -> IndexBuffer
    
    /// Create a new vertex buffer for specific length and binding.
    func makeVertexBuffer(length: Int, binding: Int) -> VertexBuffer
    
    // MARK: - Shaders
    
    /// Compile device specific shader from shader data.
    /// - Throws: Throw an error if something went wrong on compilation.
    func compileShader(from shader: Shader) throws -> CompiledShader
    
    /// Create a framebuffer from descriptor.
    func makeFramebuffer(from descriptor: FramebufferDescriptor) -> Framebuffer
    
    /// Create pipeline state from shader.
    func makeRenderPipeline(from descriptor: RenderPipelineDescriptor) -> RenderPipeline
    
    /// Create a new GPU sampler from descriptor.
    func makeSampler(from descriptor: SamplerDescriptor) -> Sampler
    
    // MARK: - Uniforms
    
    /// Create a new uniform buffer with specific length and binding.
    func makeUniformBuffer(length: Int, binding: Int) -> UniformBuffer
    
    /// Create a new empty uniform buffer set.
    func makeUniformBufferSet() -> UniformBufferSet
    
    // MARK: - Texture
    
    /// Create a new GPU Texture from descriptor.
    func makeTexture(from descriptor: TextureDescriptor) -> GPUTexture
    
    /// Get image from texture rid.
    func getImage(from texture: Texture) -> Image?
    
    // MARK: - Draw
    
    /// Begin draw for window.
    /// - Returns: ``DrawList`` which contains information about drawing.
    func beginDraw(for window: Window.ID, clearColor: Color) -> DrawList
    
    /// Begin draw to framebuffer.
    /// - Returns: ``DrawList`` which contains information about drawing.
    func beginDraw(to framebuffer: Framebuffer, clearColors: [Color]?) -> DrawList
    
    /// Draw all items from ``DrawList``.
    /// - Parameter indexCount: For each instance, the number of indices to read from the index buffer.
    /// - Parameter indexBufferOffset: Byte offset within indexBuffer to start reading indices from.
    /// - Parameter instanceCount: The number of instances to draw.
    func draw(_ list: DrawList, indexCount: Int, indexBufferOffset: Int, instanceCount: Int)
    
    /// Commit all draws from ``DrawList``.
    func endDrawList(_ drawList: DrawList)
}
