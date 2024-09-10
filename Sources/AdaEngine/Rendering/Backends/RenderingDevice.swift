//
//  RenderingDevice.swift
//  AdaEngine
//
//  Created by vladislav.prusakov on 03.09.2024.
//

/// The GPU device instance resposible for rendering and computing.
public protocol RenderingDevice: AnyObject {

    // MARK: - Buffers

    /// Create a new GPU buffer with specific length and options.
    func createBuffer(length: Int, options: ResourceOptions) -> Buffer

    /// Create a new GPU buffer with specific data, length and options.
    func createBuffer(bytes: UnsafeRawPointer, length: Int, options: ResourceOptions) -> Buffer

    /// Create a new index buffer with specific index, format, data and length.
    func createIndexBuffer(format: IndexBufferFormat, bytes: UnsafeRawPointer, length: Int) -> IndexBuffer

    /// Create a new vertex buffer for specific length and binding.
    func createVertexBuffer(length: Int, binding: Int) -> VertexBuffer

    // MARK: - Shaders

    /// Compile device specific shader from shader data.
    /// - Throws: Throw an error if something went wrong on compilation.
    func compileShader(from shader: Shader) throws -> CompiledShader

    /// Create a framebuffer from descriptor.
    func createFramebuffer(from descriptor: FramebufferDescriptor) -> Framebuffer

    /// Create pipeline state from shader.
    func createRenderPipeline(from descriptor: RenderPipelineDescriptor) -> RenderPipeline

    /// Create a new GPU sampler from descriptor.
    func createSampler(from descriptor: SamplerDescriptor) -> Sampler

    // MARK: - Uniforms

    /// Create a new uniform buffer with specific length and binding.
    func createUniformBuffer(length: Int, binding: Int) -> UniformBuffer

    /// Create a new empty uniform buffer set.
    func createUniformBufferSet() -> UniformBufferSet

    // MARK: - Texture

    /// Create a new GPU Texture from descriptor.
    func createTexture(from descriptor: TextureDescriptor) -> GPUTexture

    /// Get image from texture rid.
    func getImage(from texture: Texture) -> Image?

    // MARK: - Drawing

    func draw(
        in commandBuffer: CommandBuffer,
        vertexCount: Int,
        instanceCount: Int,
        baseVertex: Int,
        firstInstance: Int
    )

    func drawIndexed(
        in commandBuffer: CommandBuffer,
        indexCount: Int,
        instanceCount: Int,
        firstIndex: Int,
        offset: Int,
        firstInstance: Int
    )

    // TODO: Move to render backend, i think

    /// Begin draw for window.
    /// - Warning: Local RenderingDevice can't render on specific window. Instead, use global ``RenderEngine/renderingDevice`` instance.
    /// - Returns: ``DrawList`` which contains information about drawing.
    func beginDraw(
        for window: UIWindow.ID,
        clearColor: Color,
        loadAction: AttachmentLoadAction,
        storeAction: AttachmentStoreAction
    ) throws -> DrawList

    /// Begin draw to framebuffer.
    /// - Returns: ``DrawList`` which contains information about drawing.
    func beginDraw(to framebuffer: Framebuffer, clearColors: [Color]?) throws -> DrawList

    /// Draw all items from ``DrawList``.
    /// - Parameter indexCount: For each instance, the number of indices to read from the index buffer.
    /// - Parameter indexBufferOffset: Byte offset within indexBuffer to start reading indices from.
    /// - Parameter instanceCount: The number of instances to draw.
    func draw(_ list: DrawList, indexCount: Int, indexBufferOffset: Int, instanceCount: Int)

    /// Commit all draws from ``DrawList``.
    func endDrawList(_ drawList: DrawList)
}

public protocol CommandBuffer {

}

public protocol DrawCommandBuffer {

}
