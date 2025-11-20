//
//  CommandEncoder.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 29.07.2025.
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

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
}

public protocol BlitCommandEncoder: AnyObject {
    // Copies
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

    // Utilities
    func generateMipmaps(for texture: Texture)

    func fillBuffer(_ buffer: Buffer, range: Range<Int>, value: UInt8)

    func endBlitPass()
}

public protocol CommandQueue: AnyObject {
    func makeCommandBuffer() -> CommandBuffer
}

public protocol CommonCommandEncoder: AnyObject {

}

public protocol RenderCommandEncoder: CommonCommandEncoder {

    func setRenderPipelineState(_ pipeline: RenderPipeline)

    func setVertexBuffer(_ buffer: UniformBuffer, offset: Int, index: Int)

    func setFragmentBuffer(_ buffer: UniformBuffer, offset: Int, index: Int)

    func setVertexBytes(_ bytes: UnsafeRawPointer, length: Int, index: Int)

    func setFragmentTexture(_ texture: Texture, index: Int)

    func setFragmentSamplerState(_ sampler: Sampler, index: Int)

    func setViewport(_ viewport: Rect)

    func setScissorRect(_ rect: Rect)

    func setTriangleFillMode(_ fillMode: TriangleFillMode)

    func setIndexBuffer(_ buffer: IndexBuffer, offset: Int)

    func drawIndexed(indexCount: Int, indexBufferOffset: Int, instanceCount: Int)

    func endRenderPass()
}


import MetalKit

final class MetalCommandQueue: CommandQueue {

    let commandQueue: MTLCommandQueue

    init(commandQueue: MTLCommandQueue) {
        self.commandQueue = commandQueue
    }

    func makeCommandBuffer() -> CommandBuffer {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            fatalError()
        }
        return MetalCommandEncoder(commandBuffer: commandBuffer)
    }
}

import Math

final class MetalCommandEncoder: CommandBuffer {
    let commandBuffer: MTLCommandBuffer

    init(commandBuffer: MTLCommandBuffer) {
        self.commandBuffer = commandBuffer
    }

    func beginRenderPass(_ desc: RenderPassDescriptor) -> RenderCommandEncoder {
        // Create a new MTLRenderPassDescriptor
        let renderPassDescriptor = MTLRenderPassDescriptor()
        let attachments = desc.colorAttachments

        for (index, attachment) in attachments.enumerated() {
            let colorAttachment = renderPassDescriptor.colorAttachments[index]
            colorAttachment?.texture = (attachment.texture.gpuTexture as! MetalGPUTexture).texture
            colorAttachment?.loadAction = attachment.operation?.loadAction.toMetal ?? .dontCare
            colorAttachment?.storeAction = attachment.operation?.storeAction.toMetal ?? .dontCare
        }

        if let depthStencilAttachment = desc.depthStencilAttachment {
            renderPassDescriptor.depthAttachment.texture = (depthStencilAttachment.texture.gpuTexture as! MetalGPUTexture).texture
            renderPassDescriptor.depthAttachment.loadAction = depthStencilAttachment.depthOperation?.loadAction.toMetal ?? .dontCare
            renderPassDescriptor.depthAttachment.storeAction = depthStencilAttachment.depthOperation?.storeAction.toMetal ?? .dontCare
            // renderPassDescriptor.depthAttachment.clearDepth = Double(depthStencilAttachment.depthOperation?.clearDepth ?? 0)
            // renderPassDescriptor.depthAttachment.clearStencil = UInt32(depthStencilAttachment.stencilOperation?.clearStencil ?? 0)
            renderPassDescriptor.stencilAttachment.texture = (depthStencilAttachment.texture.gpuTexture as! MetalGPUTexture).texture
            renderPassDescriptor.stencilAttachment.loadAction = depthStencilAttachment.stencilOperation?.loadAction.toMetal ?? .dontCare
            renderPassDescriptor.stencilAttachment.storeAction = depthStencilAttachment.stencilOperation?.storeAction.toMetal ?? .dontCare
            // renderPassDescriptor.stencilAttachment.clearStencil = UInt32(depthStencilAttachment.stencilOperation?.clearStencil ?? 0)
        }

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            fatalError("Failed to create MTLRenderCommandEncoder")
        }
        encoder.label = desc.label

        return MetalRenderCommandEncoder(
            renderEncoder: encoder
        )
    }

    func beginBlitPass(_ desc: BlitPassDescriptor) -> BlitCommandEncoder {
        guard let encoder = commandBuffer.makeBlitCommandEncoder() else {
            fatalError("Failed to create MTLBlitCommandEncoder")
        }
        encoder.label = desc.label
        return MetalBlitCommandEncoder(blitEncoder: encoder)
    }
}

final class MetalRenderCommandEncoder: RenderCommandEncoder {

    let renderEncoder: MTLRenderCommandEncoder
    private var currentIndexBuffer: MTLBuffer?
    private var currentIndexType: MTLIndexType = .uint32

    init(renderEncoder: MTLRenderCommandEncoder) {
        self.renderEncoder = renderEncoder
    }

    func setRenderPipelineState(_ pipeline: RenderPipeline) {
        guard let metalPipeline = pipeline as? MetalRenderPipeline else {
            fatalError("RenderPipeline is not a MetalRenderPipeline")
        }
        renderEncoder.setRenderPipelineState(metalPipeline.renderPipeline)
    }

    func setVertexBuffer(_ buffer: UniformBuffer, offset: Int, index: Int) {
        guard let metalBuffer = buffer as? MetalUniformBuffer else {
            fatalError("UniformBuffer is not a MetalUniformBuffer")
        }
        renderEncoder.setVertexBuffer(metalBuffer.buffer, offset: offset, index: index)
    }

    func setFragmentBuffer(_ buffer: UniformBuffer, offset: Int, index: Int) {
        guard let metalBuffer = buffer as? MetalUniformBuffer else {
            fatalError("UniformBuffer is not a MetalUniformBuffer")
        }
        renderEncoder.setFragmentBuffer(metalBuffer.buffer, offset: offset, index: index)
    }

    func setVertexBytes(_ bytes: UnsafeRawPointer, length: Int, index: Int) {
        renderEncoder.setVertexBytes(bytes, length: length, index: index)
    }

    func setFragmentTexture(_ texture: Texture, index: Int) {
        guard let metalTexture = texture.gpuTexture as? MetalGPUTexture else {
            fatalError("Texture's gpuTexture is not a MetalGPUTexture")
        }
        renderEncoder.setFragmentTexture(metalTexture.texture, index: index)
    }

    func setFragmentSamplerState(_ sampler: Sampler, index: Int) {
        guard let metalSampler = sampler as? MetalSampler else {
            fatalError("Sampler is not a MetalSampler")
        }
        renderEncoder.setFragmentSamplerState(metalSampler.mtlSampler, index: index)
    }

    func setViewport(_ viewport: Rect) {
        renderEncoder.setViewport(MTLViewport(
            originX: Double(viewport.origin.x),
            originY: Double(viewport.origin.y),
            width: Double(viewport.size.width),
            height: Double(viewport.size.height),
            znear: 0,
            zfar: 1
        ))
    }

    func setScissorRect(_ rect: Rect) {
        renderEncoder.setScissorRect(MTLScissorRect(
            x: Int(rect.origin.x),
            y: Int(rect.origin.y),
            width: Int(rect.size.width),
            height: Int(rect.size.height)
        ))
    }

    func setTriangleFillMode(_ fillMode: TriangleFillMode) {
        renderEncoder.setTriangleFillMode(fillMode == .fill ? .fill : .lines)
    }

    func setIndexBuffer(_ buffer: IndexBuffer, offset: Int) {
        guard let metalIndexBuffer = buffer as? MetalIndexBuffer else {
            fatalError("IndexBuffer is not a MetalIndexBuffer")
        }
        self.currentIndexBuffer = metalIndexBuffer.buffer
        self.currentIndexType = (metalIndexBuffer.indexFormat == .uInt32) ? .uint32 : .uint16
    }

    func drawIndexed(indexCount: Int, indexBufferOffset: Int, instanceCount: Int) {
        guard let indexBuffer = self.currentIndexBuffer else {
            fatalError("Index buffer is not set. Call setIndexBuffer(_:offset:) before drawIndexed().")
        }
        renderEncoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: indexCount,
            indexType: self.currentIndexType,
            indexBuffer: indexBuffer,
            indexBufferOffset: indexBufferOffset,
            instanceCount: instanceCount
        )
    }

    func endRenderPass() {
        renderEncoder.endEncoding()
    }
}

// MARK: - Metal Blit Encoder

final class MetalBlitCommandEncoder: BlitCommandEncoder {
    let blitEncoder: MTLBlitCommandEncoder

    init(blitEncoder: MTLBlitCommandEncoder) {
        self.blitEncoder = blitEncoder
    }

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
    ) {
        guard
            let src = source.gpuTexture as? MetalGPUTexture,
            let dst = destination.gpuTexture as? MetalGPUTexture
        else { fatalError("Textures must be Metal textures") }

        blitEncoder.copy(
            from: src.texture,
            sourceSlice: sourceSlice,
            sourceLevel: sourceMipLevel,
            sourceOrigin: MTLOrigin(x: sourceOrigin.x, y: sourceOrigin.y, z: sourceOrigin.z),
            sourceSize: MTLSize(width: sourceSize.width, height: sourceSize.height, depth: sourceSize.depth),
            to: dst.texture,
            destinationSlice: destinationSlice,
            destinationLevel: destinationMipLevel,
            destinationOrigin: MTLOrigin(x: destinationOrigin.x, y: destinationOrigin.y, z: destinationOrigin.z)
        )
    }

    func copyBufferToBuffer(
        source: Buffer,
        sourceOffset: Int,
        destination: Buffer,
        destinationOffset: Int,
        size: Int
    ) {
        guard
            let src = source as? MetalBuffer,
            let dst = destination as? MetalBuffer
        else { fatalError("Buffers must be Metal buffers") }

        blitEncoder.copy(
            from: src.buffer,
            sourceOffset: sourceOffset,
            to: dst.buffer,
            destinationOffset: destinationOffset,
            size: size
        )
    }

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
    ) {
        guard
            let src = source as? MetalBuffer,
            let dst = destination.gpuTexture as? MetalGPUTexture
        else { fatalError("Invalid Metal resources") }

        blitEncoder.copy(
            from: src.buffer,
            sourceOffset: sourceOffset,
            sourceBytesPerRow: sourceBytesPerRow,
            sourceBytesPerImage: sourceBytesPerImage,
            sourceSize: MTLSize(width: sourceSize.width, height: sourceSize.height, depth: sourceSize.depth),
            to: dst.texture,
            destinationSlice: destinationSlice,
            destinationLevel: destinationMipLevel,
            destinationOrigin: MTLOrigin(x: destinationOrigin.x, y: destinationOrigin.y, z: destinationOrigin.z)
        )
    }

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
    ) {
        guard
            let src = source.gpuTexture as? MetalGPUTexture,
            let dst = destination as? MetalBuffer
        else { fatalError("Invalid Metal resources") }

        blitEncoder.copy(
            from: src.texture,
            sourceSlice: sourceSlice,
            sourceLevel: sourceMipLevel,
            sourceOrigin: MTLOrigin(x: sourceOrigin.x, y: sourceOrigin.y, z: sourceOrigin.z),
            sourceSize: MTLSize(width: sourceSize.width, height: sourceSize.height, depth: sourceSize.depth),
            to: dst.buffer,
            destinationOffset: destinationOffset,
            destinationBytesPerRow: destinationBytesPerRow,
            destinationBytesPerImage: destinationBytesPerImage
        )
    }

    func generateMipmaps(for texture: Texture) {
        guard let tex = texture.gpuTexture as? MetalGPUTexture else {
            fatalError("Texture must be a Metal texture")
        }
        blitEncoder.generateMipmaps(for: tex.texture)
    }

    func fillBuffer(_ buffer: Buffer, range: Range<Int>, value: UInt8) {
        guard let metalBuffer = buffer as? MetalBuffer else {
            fatalError("Buffer must be a Metal buffer")
        }
        blitEncoder.__fill(
            metalBuffer.buffer,
            range: NSRange(location: range.lowerBound, length: range.count),
            value: value
        )
    }

    func endBlitPass() {
        blitEncoder.endEncoding()
    }
}
