//
//  MetalRenderCommandEncoder.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 23.11.2025.
//

#if canImport(WebGPU)
import Math
import WebGPU
import CWebGPU

final class WGPURenderCommandEncoder: RenderCommandEncoder {

    let renderEncoder: WebGPU.RenderPassEncoder
    private var currentIndexBuffer: WebGPU.Buffer?
    private var currentIndexType: WebGPU.IndexFormat = .uint32
    private var currentPrimitiveType: WebGPU.PrimitiveTopology = .triangleList

    private var bindGroupLayouts: [WebGPU.BindGroupLayout] = []
    private var device: WebGPU.Device

    init(
        renderEncoder: WebGPU.RenderPassEncoder,
        device: WebGPU.Device
    ) {
        self.renderEncoder = renderEncoder
        self.device = device
    }

    func pushDebugName(_ string: String) {
        renderEncoder.pushDebugGroup(groupLabel: string)
    }

    func popDebugName() {
        renderEncoder.popDebugGroup()
    }

    func setRenderPipelineState(_ pipeline: RenderPipeline) {
        guard let metalPipeline = pipeline as? WGPURenderPipeline else {
            fatalError("RenderPipeline is not a MetalRenderPipeline")
        }
        // renderEncoder.setRenderPipelineState(metalPipeline.renderPipeline)
        // currentPrimitiveType = metalPipeline.descriptor.primitive.toMetal
    }

    func setVertexBuffer(_ buffer: UniformBuffer, offset: Int, index: Int) {
        guard let metalBuffer = buffer as? WGPUUniformBuffer else {
            fatalError("UniformBuffer is not a MetalUniformBuffer")
        }
        // renderEncoder.setVertexBuffer(
        //     slot: UInt32(index), 
        //     buffer: buffer.buffer, 
        //     offset: UInt64(offset), 
        //     size: UInt64(buffer.size)
        // )
    }

    func setVertexBuffer(_ buffer: VertexBuffer, offset: Int, index: Int) {
        guard let wgpuBuffer = buffer as? WGPUVertexBuffer else {
            fatalError("VertexBuffer is not a MetalVertexBuffer")
        }
        renderEncoder.setVertexBuffer(
            slot: UInt32(index), 
            buffer: wgpuBuffer.buffer, 
            offset: UInt64(offset), 
            size: UInt64(buffer.length)
        )
    }

    func setFragmentBuffer(_ buffer: UniformBuffer, offset: Int, index: Int) {
        guard let wgpuBuffer = buffer as? WGPUUniformBuffer else {
            fatalError("UniformBuffer is not a MetalUniformBuffer")
        }
        // renderEncoder.setFragmentBuffer(
        //     slot: UInt32(index), 
        //     buffer: buffer.buffer, 
        //     offset: UInt64(offset), 
        //     size: UInt64(buffer.buffer.size)
        // )
    }


    func setVertexBuffer<T>(_ bufferData: BufferData<T>, offset: Int, index: Int) {
        guard let wgpuBuffer = bufferData.buffer as? WGPUBuffer else {
            fatalError("BufferData is not a MetalBuffer")
        }

        renderEncoder.setVertexBuffer(
            slot: UInt32(index), 
            buffer: wgpuBuffer.buffer, 
            offset: UInt64(offset), 
            size: UInt64(wgpuBuffer.length)
        )
    }

    func setFragmentBuffer<T>(_ bufferData: BufferData<T>, offset: Int, index: Int) {
        guard let wgpuBuffer = bufferData.buffer as? WGPUBuffer else {
            fatalError("UniformBuffer is not a MetalUniformBuffer")
        }

        // renderEncoder.setFragmentBuffer(
        //     slot: UInt32(index), 
        //     buffer: wgpuBuffer.buffer, 
        //     offset: UInt64(offset), 
        //     size: UInt64(wgpuBuffer.length)
        // )
    }

    func setIndexBuffer<T>(_ bufferData: BufferData<T>, indexFormat: IndexBufferFormat) {
        guard let wgpuBuffer = bufferData.buffer as? WGPUBuffer else {
            fatalError("UniformBuffer is not a MetalUniformBuffer")
        }
        currentIndexBuffer = wgpuBuffer.buffer
        currentIndexType = indexFormat == .uInt32 ? .uint32 : .uint16
    }

    func setVertexBytes(_ bytes: UnsafeRawPointer, length: Int, index: Int) {
        guard let buffer = device.createBuffer(descriptor: BufferDescriptor.init(usage: BufferUsage.vertex, size: UInt64(length))) else {
            return
        }
        device.queue.writeBuffer(buffer, bufferOffset: 0, data: UnsafeRawBufferPointer(start: bytes, count: length))
        unsafe buffer.withUnsafeHandle { _buffer in
            unsafe renderEncoder.withUnsafeHandle { _handle in
                wgpuRenderPassEncoderSetVertexBuffer(_handle, UInt32(index), _buffer, UInt64(length), UInt64(length))
            }
        }

    }

    func setFragmentTexture(_ texture: Texture, index: Int) {
        guard let wgpuTexture = texture.gpuTexture as? WGPUGPUTexture else {
            fatalError("Texture's gpuTexture is not a MetalGPUTexture")
        }
        // renderEncoder.setFragmentTexture(
        //     texture: wgpuTexture.texture, 
        //     index: UInt32(index)
        // )
    }

    func setFragmentSamplerState(_ sampler: Sampler, index: Int) {
        guard let wgpuSampler = sampler as? WGPUSampler else {
            fatalError("Sampler is not a MetalSampler")
        }
        // renderEncoder.setFragmentSamplerState(metalSampler.wgpuSampler, index: index)
    }

    func setViewport(_ viewport: Rect) {
        renderEncoder.setViewport(
            x: Float(viewport.origin.x), 
            y: Float(viewport.origin.y), 
            width: Float(viewport.size.width), 
            height: Float(viewport.size.height), 
            minDepth: 0, 
            maxDepth: 1
        )
    }

    func setScissorRect(_ rect: Rect) {
        renderEncoder.setScissorRect(
            x: UInt32(rect.origin.x), 
            y: UInt32(rect.origin.y), 
            width: UInt32(rect.size.width), 
            height: UInt32(rect.size.height)
        )
    }

    func setTriangleFillMode(_ fillMode: TriangleFillMode) {
        // renderEncoder.setTriangleFillMode(fillMode == .fill ? .fill : .lines)
    }

    func setIndexBuffer(_ buffer: IndexBuffer, offset: Int) {
        guard let wgpuIndexBuffer = buffer as? WGPUIndexBuffer else {
            fatalError("IndexBuffer is not a WGPUIndexBuffer")
        }
        self.currentIndexBuffer = wgpuIndexBuffer.buffer
        self.currentIndexType = (wgpuIndexBuffer.indexFormat == .uInt32) ? .uint32 : .uint16
    }

    func drawIndexed(indexCount: Int, indexBufferOffset: Int, instanceCount: Int) {
        guard let indexBuffer = self.currentIndexBuffer else {
            fatalError("Index buffer is not set. Call setIndexBuffer(_:offset:) before drawIndexed().")
        }
        renderEncoder.drawIndexedIndirect(indirectBuffer: indexBuffer, indirectOffset: UInt64(indexBufferOffset))
    }

    func draw(type: IndexPrimitive, vertexStart: Int, vertexCount: Int, instanceCount: Int) {
        renderEncoder.draw(vertexCount: UInt32(vertexCount), instanceCount: UInt32(instanceCount), firstVertex: UInt32(vertexStart), firstInstance: UInt32(0))
    }

    func endRenderPass() {
        renderEncoder.end()
    }
}
#endif
