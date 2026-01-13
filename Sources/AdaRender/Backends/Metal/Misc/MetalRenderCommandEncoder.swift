//
//  MetalRenderCommandEncoder.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 23.11.2025.
//

#if canImport(Metal)
import Math
import Metal

final class MetalRenderCommandEncoder: RenderCommandEncoder {

    let renderEncoder: MTLRenderCommandEncoder
    private var currentIndexBuffer: MTLBuffer?
    private var currentIndexType: MTLIndexType = .uint32
    private var currentPrimitiveType: MTLPrimitiveType = .triangle

    init(renderEncoder: MTLRenderCommandEncoder) {
        self.renderEncoder = renderEncoder
    }

    func pushDebugName(_ string: String) {
        renderEncoder.pushDebugGroup(string)
    }

    func popDebugName() {
        renderEncoder.popDebugGroup()
    }

    func setRenderPipelineState(_ pipeline: RenderPipeline) {
        guard let metalPipeline = pipeline as? MetalRenderPipeline else {
            fatalError("RenderPipeline is not a MetalRenderPipeline")
        }
        renderEncoder.setRenderPipelineState(metalPipeline.renderPipeline)
        currentPrimitiveType = metalPipeline.descriptor.primitive.toMetal
    }

    func setVertexBuffer(_ buffer: UniformBuffer, offset: Int, slot: Int) {
        guard let metalBuffer = buffer as? MetalUniformBuffer else {
            fatalError("UniformBuffer is not a MetalUniformBuffer")
        }
        renderEncoder.setVertexBuffer(metalBuffer.buffer, offset: offset, index: slot)
    }

    func setVertexBuffer(_ buffer: VertexBuffer, offset: Int, slot: Int) {
        guard let metalBuffer = buffer as? MetalVertexBuffer else {
            fatalError("VertexBuffer is not a MetalVertexBuffer")
        }
        renderEncoder.setVertexBuffer(metalBuffer.buffer, offset: offset, index: slot)
    }

    func setFragmentBuffer(_ buffer: UniformBuffer, offset: Int, slot: Int) {
        guard let metalBuffer = buffer as? MetalUniformBuffer else {
            fatalError("UniformBuffer is not a MetalUniformBuffer")
        }
        renderEncoder.setFragmentBuffer(metalBuffer.buffer, offset: offset, index: slot)
    }


    func setVertexBuffer<T>(_ bufferData: BufferData<T>, offset: Int, slot: Int) {
        guard let metalBuffer = bufferData.buffer as? MetalBuffer else {
            fatalError("BufferData is not a MetalBuffer")
        }

        renderEncoder.setVertexBuffer(metalBuffer.buffer, offset: offset, index: slot)
    }

    func setFragmentBuffer<T>(_ bufferData: BufferData<T>, offset: Int, slot: Int) {
        guard let metalBuffer = bufferData.buffer as? MetalBuffer else {
            fatalError("UniformBuffer is not a MetalUniformBuffer")
        }

        renderEncoder.setFragmentBuffer(metalBuffer.buffer, offset: offset, index: slot)
    }

    func setIndexBuffer<T>(_ bufferData: BufferData<T>, indexFormat: IndexBufferFormat) {
        guard let metalBuffer = bufferData.buffer as? MetalBuffer else {
            fatalError("UniformBuffer is not a MetalUniformBuffer")
        }
        currentIndexBuffer = metalBuffer.buffer
        currentIndexType = indexFormat == .uInt32 ? .uint32 : .uint16
    }

    func setVertexBytes(_ bytes: UnsafeRawPointer, length: Int, slot: Int) {
        unsafe renderEncoder.setVertexBytes(bytes, length: length, index: slot)
    }

    func setFragmentTexture(_ texture: Texture, slot: Int) {
        guard let metalTexture = texture.gpuTexture as? MetalGPUTexture else {
            fatalError("Texture's gpuTexture is not a MetalGPUTexture")
        }
        renderEncoder.setFragmentTexture(metalTexture.texture, index: slot)
    }

    func setFragmentSamplerState(_ sampler: Sampler, slot: Int) {
        guard let metalSampler = sampler as? MetalSampler else {
            fatalError("Sampler is not a MetalSampler")
        }
        renderEncoder.setFragmentSamplerState(metalSampler.mtlSampler, index: slot)
    }

    func setViewport(_ viewport: Rect) {
        renderEncoder.setViewport(
            MTLViewport(
                originX: Double(viewport.origin.x),
                originY: Double(viewport.origin.y),
                width: Double(viewport.size.width),
                height: Double(viewport.size.height),
                znear: 0,
                zfar: 1
            )
        )
    }

    func setScissorRect(_ rect: Rect) {
        renderEncoder.setScissorRect(
            MTLScissorRect(
                x: Int(rect.origin.x),
                y: Int(rect.origin.y),
                width: Int(rect.size.width),
                height: Int(rect.size.height)
            )
        )
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
            type: currentPrimitiveType,
            indexCount: indexCount,
            indexType: self.currentIndexType,
            indexBuffer: indexBuffer,
            indexBufferOffset: indexBufferOffset,
            instanceCount: instanceCount
        )
    }

    func draw(type: IndexPrimitive, vertexStart: Int, vertexCount: Int, instanceCount: Int) {
        renderEncoder.drawPrimitives(
            type: type.toMetal,
            vertexStart: vertexStart,
            vertexCount: vertexCount,
            instanceCount: instanceCount
        )
    }

    func endRenderPass() {
        renderEncoder.endEncoding()
    }
}
#endif
