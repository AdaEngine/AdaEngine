//
//  CommandEncoder.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 29.07.2025.
//

import AdaUtils
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import Math

// MARK: - Common Descriptors

public struct BlitPassDescriptor: Sendable {
    public var label: String?

    public init(label: String? = nil) {
        self.label = label
    }
}

// MARK: - Common Types

public struct Origin3D: Sendable {
    public var x: Int
    public var y: Int
    public var z: Int

    public init(x: Int = 0, y: Int = 0, z: Int = 0) {
        self.x = x
        self.y = y
        self.z = z
    }
}

public struct Size3D: Sendable {
    public var width: Int
    public var height: Int
    public var depth: Int

    public init(width: Int, height: Int, depth: Int = 1) {
        self.width = width
        self.height = height
        self.depth = depth
    }
}

public protocol CommandBuffer: AnyObject {
    func beginRenderPass(_ desc: RenderPassDescriptor) -> RenderCommandEncoder

    func beginBlitPass(_ desc: BlitPassDescriptor) -> BlitCommandEncoder
    
    func commit()
}

public protocol BlitCommandEncoder: CommonCommandEncoder {
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

    func copyBufferToBuffer(
        source: Buffer,
        sourceOffset: Int,
        destination: Buffer,
        destinationOffset: Int,
        size: Int
    )

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

    func generateMipmaps(for texture: Texture)

    func fillBuffer(_ buffer: Buffer, range: Range<Int>, value: UInt8)

    func endBlitPass()
}

public protocol CommandQueue: AnyObject {
    func makeCommandBuffer() -> CommandBuffer
}

public protocol CommonCommandEncoder: AnyObject {
    func pushDebugName(_ string: String)

    func popDebugName()
}

public protocol RenderCommandEncoder: CommonCommandEncoder {

    func setRenderPipelineState(_ pipeline: RenderPipeline)

    func setVertexBuffer(_ buffer: UniformBuffer, offset: Int, index: Int)

    func setVertexBuffer(_ buffer: VertexBuffer, offset: Int, index: Int)

    func setFragmentBuffer(_ buffer: UniformBuffer, offset: Int, index: Int)

    func setVertexBuffer<T>(_ bufferData: BufferData<T>, offset: Int, index: Int)

    func setFragmentBuffer<T>(_ bufferData: BufferData<T>, offset: Int, index: Int)

    func setIndexBuffer<T>(_ bufferData: BufferData<T>, indexFormat: IndexBufferFormat)

    func setVertexBytes(_ bytes: UnsafeRawPointer, length: Int, index: Int)

    func setFragmentTexture(_ texture: Texture, index: Int)

    func setFragmentSamplerState(_ sampler: Sampler, index: Int)

    func setViewport(_ viewport: Rect)

    func setScissorRect(_ rect: Rect)

    func setTriangleFillMode(_ fillMode: TriangleFillMode)

    func setIndexBuffer(_ buffer: IndexBuffer, offset: Int)

    func drawIndexed(indexCount: Int, indexBufferOffset: Int, instanceCount: Int)

    func draw(type: IndexPrimitive, vertexStart: Int, vertexCount: Int, instanceCount: Int)

    func endRenderPass()
}
