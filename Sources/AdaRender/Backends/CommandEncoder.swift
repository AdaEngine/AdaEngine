//
//  CommandEncoder.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 29.07.2025.
//

import AdaUtils
import Foundation
import Math

// MARK: - Common Descriptors

/// A descriptor that configures a blit (block transfer) pass.
///
/// Blit passes are used to copy data between textures and buffers,
/// generate mipmaps, and perform other memory transfer operations.
public struct BlitPassDescriptor: Sendable {
    /// An optional debug label for the blit pass.
    ///
    /// This label appears in GPU debugging tools to help identify the pass.
    public var label: String?

    /// Creates a new blit pass descriptor.
    ///
    /// - Parameter label: An optional debug label for the pass.
    public init(label: String? = nil) {
        self.label = label
    }
}

// MARK: - Common Types

/// Represents a 3D origin point in texture or buffer space.
///
/// Used to specify the starting position for texture and buffer copy operations.
public struct Origin3D: Sendable {
    /// The x-coordinate of the origin.
    public var x: Int
    
    /// The y-coordinate of the origin.
    public var y: Int
    
    /// The z-coordinate of the origin (for 3D textures or texture arrays).
    public var z: Int

    /// Creates a new 3D origin.
    ///
    /// - Parameters:
    ///   - x: The x-coordinate. Defaults to 0.
    ///   - y: The y-coordinate. Defaults to 0.
    ///   - z: The z-coordinate. Defaults to 0.
    public init(x: Int = 0, y: Int = 0, z: Int = 0) {
        self.x = x
        self.y = y
        self.z = z
    }
}

/// Represents a 3D size in texture or buffer space.
///
/// Used to specify the dimensions of regions in texture and buffer copy operations.
public struct Size3D: Sendable {
    /// The width of the region in pixels or elements.
    public var width: Int
    
    /// The height of the region in pixels or elements.
    public var height: Int
    
    /// The depth of the region (for 3D textures or texture arrays).
    public var depth: Int

    /// Creates a new 3D size.
    ///
    /// - Parameters:
    ///   - width: The width of the region.
    ///   - height: The height of the region.
    ///   - depth: The depth of the region. Defaults to 1 for 2D textures.
    public init(width: Int, height: Int, depth: Int = 1) {
        self.width = width
        self.height = height
        self.depth = depth
    }
}

// MARK: - Command Buffer

/// A container that stores encoded GPU commands.
///
/// Command buffers are created from a ``CommandQueue`` and used to encode
/// rendering and blit operations. Once all commands are encoded, call ``commit()``
/// to submit the buffer to the GPU for execution.
///
/// ## Usage
/// ```swift
/// let commandBuffer = commandQueue.makeCommandBuffer()
/// let encoder = commandBuffer.beginRenderPass(descriptor)
/// // ... encode rendering commands ...
/// encoder.endRenderPass()
/// commandBuffer.commit()
/// ```
public protocol CommandBuffer: AnyObject {
    /// The debug label for the command buffer.
    var label: String? { get set }

    /// Begins a render pass and returns an encoder for recording rendering commands.
    ///
    /// - Parameter desc: The descriptor that configures the render pass attachments and load/store actions.
    /// - Returns: A ``RenderCommandEncoder`` for encoding rendering commands.
    func beginRenderPass(_ desc: RenderPassDescriptor) -> RenderCommandEncoder

    /// Begins a blit pass and returns an encoder for recording memory transfer commands.
    ///
    /// - Parameter desc: The descriptor that configures the blit pass.
    /// - Returns: A ``BlitCommandEncoder`` for encoding blit commands.
    func beginBlitPass(_ desc: BlitPassDescriptor) -> BlitCommandEncoder
    
    /// Commits the command buffer for execution on the GPU.
    ///
    /// After calling this method, the command buffer is submitted to the GPU
    /// and cannot be modified further.
    func commit()
}

// MARK: - Blit Command Encoder

/// An encoder for recording memory transfer (blit) commands.
///
/// Use a blit command encoder to copy data between textures and buffers,
/// generate mipmaps, and fill buffers with a constant value.
///
/// Blit encoders are created from a ``CommandBuffer`` using ``CommandBuffer/beginBlitPass(_:)``.
/// When finished encoding commands, call ``endBlitPass()`` to finalize the encoder.
public protocol BlitCommandEncoder: CommonCommandEncoder {
    /// Copies a region from one texture to another.
    ///
    /// - Parameters:
    ///   - source: The source texture to copy from.
    ///   - sourceOrigin: The origin point in the source texture.
    ///   - sourceSize: The size of the region to copy.
    ///   - sourceMipLevel: The mip level of the source texture.
    ///   - sourceSlice: The slice of the source texture (for texture arrays or cube maps).
    ///   - destination: The destination texture to copy to.
    ///   - destinationOrigin: The origin point in the destination texture.
    ///   - destinationMipLevel: The mip level of the destination texture.
    ///   - destinationSlice: The slice of the destination texture.
    func copyTextureToTexture(
        source: Texture,
        sourceOrigin: Origin3D,
        sourceSize: Size3D,
        sourceMipLevel: Int,
        sourceSlice: Int,
        destination: Texture,
        destinationOrigin: Origin3D,
        destinationMipLevel: Int,
        destinationSlice: Int
    )

    /// Copies data from one buffer to another.
    ///
    /// - Parameters:
    ///   - source: The source buffer to copy from.
    ///   - sourceOffset: The byte offset in the source buffer.
    ///   - destination: The destination buffer to copy to.
    ///   - destinationOffset: The byte offset in the destination buffer.
    ///   - size: The number of bytes to copy.
    func copyBufferToBuffer(
        source: Buffer,
        sourceOffset: Int,
        destination: Buffer,
        destinationOffset: Int,
        size: Int
    )

    /// Copies data from a buffer to a texture.
    ///
    /// - Parameters:
    ///   - source: The source buffer containing image data.
    ///   - sourceOffset: The byte offset in the source buffer.
    ///   - sourceBytesPerRow: The number of bytes per row in the source data.
    ///   - sourceBytesPerImage: The number of bytes per image slice (for 3D textures).
    ///   - sourceSize: The size of the image region to copy.
    ///   - destination: The destination texture.
    ///   - destinationOrigin: The origin point in the destination texture.
    ///   - destinationMipLevel: The mip level of the destination texture.
    ///   - destinationSlice: The slice of the destination texture.
    func copyBufferToTexture(
        source: Buffer,
        sourceOffset: Int,
        sourceBytesPerRow: Int,
        sourceBytesPerImage: Int,
        sourceSize: Size3D,
        destination: Texture,
        destinationOrigin: Origin3D,
        destinationMipLevel: Int,
        destinationSlice: Int
    )

    /// Copies data from a texture to a buffer.
    ///
    /// - Parameters:
    ///   - source: The source texture.
    ///   - sourceOrigin: The origin point in the source texture.
    ///   - sourceMipLevel: The mip level of the source texture.
    ///   - sourceSlice: The slice of the source texture.
    ///   - sourceSize: The size of the region to copy.
    ///   - destination: The destination buffer.
    ///   - destinationOffset: The byte offset in the destination buffer.
    ///   - destinationBytesPerRow: The number of bytes per row in the destination buffer.
    ///   - destinationBytesPerImage: The number of bytes per image slice in the destination.
    func copyTextureToBuffer(
        source: Texture,
        sourceOrigin: Origin3D,
        sourceMipLevel: Int,
        sourceSlice: Int,
        sourceSize: Size3D,
        destination: Buffer,
        destinationOffset: Int,
        destinationBytesPerRow: Int,
        destinationBytesPerImage: Int
    )

    /// Generates mipmaps for a texture.
    ///
    /// The GPU generates all mip levels for the specified texture based on the
    /// contents of the base mip level (level 0).
    ///
    /// - Parameter texture: The texture to generate mipmaps for.
    func generateMipmaps(for texture: Texture)

    /// Fills a buffer region with a constant byte value.
    ///
    /// - Parameters:
    ///   - buffer: The buffer to fill.
    ///   - range: The byte range within the buffer to fill.
    ///   - value: The byte value to fill with.
    func fillBuffer(_ buffer: Buffer, range: Range<Int>, value: UInt8)

    /// Ends the blit pass encoding.
    ///
    /// Call this method when you have finished encoding blit commands.
    /// After calling this method, the encoder cannot be used to encode
    /// additional commands.
    func endBlitPass()
}

// MARK: - Command Queue

/// A queue that creates command buffers for GPU submission.
///
/// Command queues represent a connection to the GPU and are used to create
/// command buffers that can be filled with rendering or compute commands.
public protocol CommandQueue: AnyObject {
    /// Creates a new command buffer for encoding GPU commands.
    ///
    /// - Returns: A new ``CommandBuffer`` ready for encoding commands.
    func makeCommandBuffer() -> CommandBuffer
}

// MARK: - Common Command Encoder

/// A base protocol for all command encoders that provides debug labeling support.
///
/// This protocol is inherited by both ``RenderCommandEncoder`` and ``BlitCommandEncoder``
/// to provide consistent debugging capabilities across all encoder types.
public protocol CommonCommandEncoder: AnyObject {
    /// Pushes a debug group name onto the encoder's debug stack.
    ///
    /// Debug names appear in GPU debugging tools (such as Xcode's GPU Frame Debugger
    /// or RenderDoc) to help identify groups of related commands.
    ///
    /// - Parameter string: The debug name to push.
    ///
    /// - Note: Each call to this method must be balanced with a call to ``popDebugName()``.
    func pushDebugName(_ string: String)

    /// Pops the most recent debug group name from the encoder's debug stack.
    ///
    /// Call this method to end a debug group started with ``pushDebugName(_:)``.
    func popDebugName()
}

// MARK: - Render Command Encoder

/// An encoder for recording rendering commands within a render pass.
///
/// Use a render command encoder to set pipeline state, bind resources (buffers, textures),
/// configure viewport and scissor rectangles, and issue draw calls.
///
/// Render encoders are created from a ``CommandBuffer`` using ``CommandBuffer/beginRenderPass(_:)``.
/// When finished encoding commands, call ``endRenderPass()`` to finalize the encoder.
///
/// ## Usage
/// ```swift
/// let encoder = commandBuffer.beginRenderPass(descriptor)
/// encoder.setRenderPipelineState(pipeline)
/// encoder.setVertexBuffer(vertexBuffer, offset: 0, slot: 0)
/// encoder.setIndexBuffer(indexBuffer, indexFormat: .uInt32)
/// encoder.drawIndexed(indexCount: 6, indexBufferOffset: 0, instanceCount: 1)
/// encoder.endRenderPass()
/// ```
public protocol RenderCommandEncoder: CommonCommandEncoder {

    /// Sets the render pipeline state for subsequent draw calls.
    ///
    /// The pipeline state defines the shaders, vertex layout, blending, and other
    /// fixed-function state used for rendering.
    ///
    /// - Parameter pipeline: The render pipeline to use.
    func setRenderPipelineState(_ pipeline: RenderPipeline)

    /// Binds a uniform buffer to a vertex shader binding point.
    ///
    /// - Parameters:
    ///   - buffer: The uniform buffer to bind.
    ///   - offset: The byte offset within the buffer.
    ///   - slot: The binding slot in the vertex shader.
    func setVertexBuffer(_ buffer: UniformBuffer, offset: Int, slot: Int)

    /// Binds a vertex buffer to a vertex shader binding point.
    ///
    /// - Parameters:
    ///   - buffer: The vertex buffer to bind.
    ///   - offset: The byte offset within the buffer.
    ///   - slot: The binding index in the vertex shader.
    func setVertexBuffer(_ buffer: VertexBuffer, offset: Int, slot: Int)

    /// Binds a uniform buffer to a fragment shader binding point.
    ///
    /// - Parameters:
    ///   - buffer: The uniform buffer to bind.
    ///   - offset: The byte offset within the buffer.
    ///   - slot: The binding slot in the fragment shader.
    func setFragmentBuffer(_ buffer: UniformBuffer, offset: Int, slot: Int)

    /// Binds buffer data to a vertex shader binding point.
    ///
    /// This method binds a ``BufferData`` container, which manages GPU buffer
    /// allocation and updates.
    ///
    /// - Parameters:
    ///   - bufferData: The buffer data container to bind.
    ///   - offset: The byte offset within the buffer.
    ///   - slot: The binding slot in the vertex shader.
    func setVertexBuffer<T>(_ bufferData: BufferData<T>, offset: Int, slot: Int)

    /// Binds buffer data to a fragment shader binding point.
    ///
    /// - Parameters:
    ///   - bufferData: The buffer data container to bind.
    ///   - offset: The byte offset within the buffer.
    ///   - slot: The binding slot in the fragment shader.
    func setFragmentBuffer<T>(_ bufferData: BufferData<T>, offset: Int, slot: Int)

    /// Sets the index buffer for indexed draw calls.
    ///
    /// - Parameters:
    ///   - bufferData: The buffer data containing indices.
    ///   - indexFormat: The format of the indices (`.uInt16` or `.uInt32`).
    func setIndexBuffer<T>(_ bufferData: BufferData<T>, indexFormat: IndexBufferFormat)

    /// Sets raw bytes as vertex shader data.
    ///
    /// Use this method for small amounts of data that change frequently.
    /// For larger or less frequently changing data, use a buffer instead.
    ///
    /// - Parameters:
    ///   - bytes: A pointer to the data.
    ///   - length: The length of the data in bytes.
    ///   - slot: The binding slot in the vertex shader.
    func setVertexBytes(_ bytes: UnsafeRawPointer, length: Int, slot: Int)

    /// Binds a texture to a fragment shader binding point.
    ///
    /// - Parameters:
    ///   - texture: The texture to bind.
    ///   - slot: The binding slot in the fragment shader.
    func setFragmentTexture(_ texture: Texture, slot: Int)

    /// Binds a sampler state to a fragment shader binding point.
    ///
    /// The sampler controls how textures are filtered and addressed during sampling.
    ///
    /// - Parameters:
    ///   - sampler: The sampler state to bind.
    ///   - slot: The binding index in the fragment shader.
    func setFragmentSamplerState(_ sampler: Sampler, slot: Int)

    /// Sets the viewport for rendering.
    ///
    /// The viewport defines the region of the render target where rendering occurs.
    /// Coordinates outside this region are clipped.
    ///
    /// - Parameter viewport: The viewport rectangle in pixels.
    func setViewport(_ viewport: Rect)

    /// Sets the scissor rectangle for rendering.
    ///
    /// Pixels outside the scissor rectangle are discarded. Unlike the viewport,
    /// the scissor test does not transform coordinates.
    ///
    /// - Parameter rect: The scissor rectangle in pixels.
    func setScissorRect(_ rect: Rect)

    /// Sets the triangle fill mode for rasterization.
    ///
    /// Use this to switch between solid fill and wireframe rendering.
    ///
    /// - Parameter fillMode: The fill mode to use (`.fill` or `.lines`).
    func setTriangleFillMode(_ fillMode: TriangleFillMode)

    /// Sets the index buffer for indexed draw calls.
    ///
    /// - Parameters:
    ///   - buffer: The index buffer to use.
    ///   - offset: The byte offset within the buffer.
    func setIndexBuffer(_ buffer: IndexBuffer, offset: Int)

    /// Issues an indexed draw call.
    ///
    /// Draws primitives using indices from the currently bound index buffer.
    /// The primitive type is determined by the current render pipeline state.
    ///
    /// - Parameters:
    ///   - indexCount: The number of indices to draw.
    ///   - indexBufferOffset: The byte offset in the index buffer to start reading from.
    ///   - instanceCount: The number of instances to draw.
    func drawIndexed(indexCount: Int, indexBufferOffset: Int, instanceCount: Int)

    /// Issues a non-indexed draw call.
    ///
    /// Draws primitives using sequential vertices from the currently bound vertex buffers.
    ///
    /// - Parameters:
    ///   - type: The primitive type to draw.
    ///   - vertexStart: The index of the first vertex to draw.
    ///   - vertexCount: The number of vertices to draw.
    ///   - instanceCount: The number of instances to draw.
    func draw(type: IndexPrimitive, vertexStart: Int, vertexCount: Int, instanceCount: Int)

    /// Ends the render pass encoding.
    ///
    /// Call this method when you have finished encoding rendering commands.
    /// After calling this method, the encoder cannot be used to encode
    /// additional commands.
    func endRenderPass()
}

// MARK: - RenderCommandEncoder Extension

public extension RenderCommandEncoder {
    /// Convenience method to set a value directly as vertex buffer data.
    ///
    /// This method copies the value's bytes directly to the GPU, making it
    /// suitable for small, frequently changing uniform data.
    ///
    /// - Parameters:
    ///   - value: The value to send to the vertex shader.
    ///   - index: The binding index in the vertex shader.
    @inlinable
    func setVertexBuffer<T>(_ value: T, slot: Int) {
        unsafe withUnsafeBytes(of: value) { ptr in
            unsafe self.setVertexBytes(ptr.baseAddress!, length: MemoryLayout<T>.stride, slot: slot)
        }
    }
}
