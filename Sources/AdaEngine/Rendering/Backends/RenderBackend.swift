//
//  RenderBackend.swift
//  AdaEngine
//
//  Created by v.prusakov on 10/9/21.
//

import Math

public enum TriangleFillMode {
    case fill
    case lines
}

/// This protocol describe interface for GPU.
protocol RenderBackend: AnyObject {

    /// Returns current frame index. Min value 0, Max value is equal ``RenderEngine/Configuration/maxFramesInFlight`` value.
    var currentFrameIndex: Int { get }

    /// Returns global ``RenderDevice``.
    var renderDevice: RenderDevice { get }

    /// Create a local render device, that can render only in texture.
    func createLocalRenderDevice() -> RenderDevice

    /// Register a new render window for render backend.
    /// Window in this case is entity that managed a drawables (aka swapchain).
    /// - Throws: Throw error if something went wrong.
    @MainActor func createWindow(_ windowId: UIWindow.ID, for surface: RenderSurface, size: SizeInt) throws

    /// Resize registred render window.
    /// - Throws: Throw error if window is not registred.
    @MainActor func resizeWindow(_ windowId: UIWindow.ID, newSize: SizeInt) throws

    /// Destroy render window from render backend.
    /// - Throws: Throw error if window is not registred.
    @MainActor func destroyWindow(_ windowId: UIWindow.ID) throws

    /// Begin rendering a frame for all windows.
    @MainActor func beginFrame() throws

    /// Release any data associated with the current frame.
    @MainActor func endFrame() throws
}

/// The GPU device instance resposible for rendering and computing.
public protocol RenderDevice: AnyObject {

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

    // MARK: - Draw

    /// Begin draw for window.
    /// - Warning: Local RenderDevice can't render on specific window. Instead, use global ``RenderEngine/renderDevice`` instance.
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
