//
//  WGPURenderCommandEncoder.swift
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
    private var currentPipeline: WGPURenderPipeline?
    
    private var device: WebGPU.Device
    
    // Track if bind group needs update
    private var bindGroupDirty: Bool = false
    private var triangleFillMode: TriangleFillMode = .fill

    struct BindGroupSlot: Hashable {
        let bindingSlot: Int
        let visibility: WebGPU.ShaderStage.RawValue
    }
    
    // Resource caches for building bind groups - key is the shader binding index
    private var uniformBuffers: [BindGroupSlot: (buffer: WebGPU.Buffer, offset: Int)] = [:]
    private var textures: [Int: WGPUGPUTexture] = [:]
    private var samplers: [Int: WGPUSampler] = [:]

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
        guard let wgpuPipeline = pipeline as? WGPURenderPipeline else {
            fatalError("RenderPipeline is not a WGPURenderPipeline")
        }
        renderEncoder.setPipeline(wgpuPipeline.renderPipeline)
        self.currentPipeline = wgpuPipeline
        
        // Update bind groups now that we have the pipeline
        if bindGroupDirty {
            commitBindGroup()
        }
    }

    func setVertexBuffer(_ buffer: UniformBuffer, offset: Int, slot: Int) {
        guard let wgpuBuffer = buffer as? WGPUUniformBuffer else {
            fatalError("UniformBuffer is not a WGPUUniformBuffer")
        }
         renderEncoder.setVertexBuffer(
            slot: UInt32(slot), 
            buffer: wgpuBuffer.buffer, 
            offset: UInt64(offset), 
            size: UInt64(buffer.length)
        )
    }

    func setVertexBuffer(_ buffer: VertexBuffer, offset: Int, slot: Int) {
        guard let wgpuBuffer = buffer as? WGPUVertexBuffer else {
            fatalError("VertexBuffer is not a WGPUVertexBuffer")
        }
        renderEncoder.setVertexBuffer(
            slot: UInt32(slot), 
            buffer: wgpuBuffer.buffer, 
            offset: UInt64(offset), 
            size: UInt64(buffer.length)
        )
    }

    func setFragmentBuffer(_ buffer: UniformBuffer, offset: Int, slot: Int) {
        guard let wgpuBuffer = buffer as? WGPUUniformBuffer else {
            fatalError("UniformBuffer is not a WGPUUniformBuffer")
        }
        // Fragment uniforms go after vertex uniforms
        uniformBuffers[BindGroupSlot(bindingSlot: slot, visibility: WebGPU.ShaderStage.fragment.rawValue)] = (buffer: wgpuBuffer.buffer, offset: offset)
        bindGroupDirty = true
    }

    func setVertexBuffer<T>(_ bufferData: BufferData<T>, offset: Int, slot: Int) {
        guard let wgpuBuffer = bufferData.buffer as? WGPUBuffer else {
            fatalError("BufferData is not a WGPUBuffer")
        }

        renderEncoder.setVertexBuffer(
            slot: UInt32(slot), 
            buffer: wgpuBuffer.buffer, 
            offset: UInt64(offset), 
            size: UInt64(wgpuBuffer.length)
        )
    }

    func setFragmentBuffer<T>(_ bufferData: BufferData<T>, offset: Int, slot: Int) {
        guard let wgpuBuffer = bufferData.buffer as? WGPUBuffer else {
            fatalError("BufferData is not a WGPUBuffer")
        }

        let uniform = WGPUUniformBuffer(buffer: wgpuBuffer.buffer, device: device, binding: slot)
        uniform.label = bufferData.label
        uniformBuffers[BindGroupSlot(bindingSlot: slot, visibility: WebGPU.ShaderStage.fragment.rawValue)] = (buffer: uniform.buffer, offset: offset)
        bindGroupDirty = true
    }

    func setIndexBuffer<T>(_ bufferData: BufferData<T>, indexFormat: IndexBufferFormat) {
        guard let wgpuBuffer = bufferData.buffer as? WGPUBuffer else {
            fatalError("BufferData is not a WGPUBuffer")
        }
        currentIndexBuffer = wgpuBuffer.buffer
        currentIndexType = indexFormat == .uInt32 ? .uint32 : .uint16
        renderEncoder.setIndexBuffer(
            wgpuBuffer.buffer,
            format: currentIndexType,
            offset: 0,
            size: UInt64(wgpuBuffer.length)
        )
    }

    func setVertexBytes(_ bytes: UnsafeRawPointer, length: Int, slot: Int) {
        guard let buffer = device.createBuffer(
            descriptor: BufferDescriptor(
                usage: [.uniform, .copyDst],
                size: UInt64(length)
            )
        ) else {
            return
        }
        unsafe device.queue.writeBuffer(
            buffer,
            bufferOffset: 0,
            data: UnsafeRawBufferPointer(start: bytes, count: length)
        )
        uniformBuffers[BindGroupSlot(bindingSlot: slot, visibility: WebGPU.ShaderStage.vertex.rawValue)] = (buffer: buffer, offset: 0)
        bindGroupDirty = true
    }

    func setFragmentTexture(_ texture: Texture, slot: Int) {
        guard let wgpuTexture = texture.gpuTexture as? WGPUGPUTexture else {
            fatalError("Texture's gpuTexture is not a WGPUGPUTexture")
        }
        textures[slot] = wgpuTexture
        bindGroupDirty = true
    }

    func setFragmentSamplerState(_ sampler: Sampler, slot: Int) {
        guard let wgpuSampler = sampler as? WGPUSampler else {
            fatalError("Sampler is not a WGPUSampler")
        }
        samplers[slot] = wgpuSampler
        bindGroupDirty = true
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

    }

    func setIndexBuffer(_ buffer: IndexBuffer, offset: Int) {
        guard let wgpuIndexBuffer = buffer as? WGPUIndexBuffer else {
            fatalError("IndexBuffer is not a WGPUIndexBuffer")
        }
        self.currentIndexBuffer = wgpuIndexBuffer.buffer
        self.currentIndexType = (wgpuIndexBuffer.indexFormat == .uInt32) ? .uint32 : .uint16
        renderEncoder.setIndexBuffer(
            wgpuIndexBuffer.buffer,
            format: currentIndexType,
            offset: UInt64(offset),
            size: UInt64(buffer.length - offset)
        )
    }

    func drawIndexed(indexCount: Int, indexBufferOffset: Int, instanceCount: Int) {
        guard currentIndexBuffer != nil else {
            fatalError("Index buffer is not set. Call setIndexBuffer(_:offset:) before drawIndexed().")
        }
        
        // Ensure bind groups are committed before drawing
        if bindGroupDirty {
            commitBindGroup()
        }
        
        renderEncoder.drawIndexed(
            indexCount: UInt32(indexCount),
            instanceCount: UInt32(instanceCount),
            firstIndex: UInt32(indexBufferOffset / (currentIndexType == .uint32 ? 4 : 2)),
            baseVertex: 0,
            firstInstance: 0
        )
    }

    func draw(type: IndexPrimitive, vertexStart: Int, vertexCount: Int, instanceCount: Int) {
        // Ensure bind groups are committed before drawing
        if bindGroupDirty {
            commitBindGroup()
        }
        
        renderEncoder.draw(
            vertexCount: UInt32(vertexCount),
            instanceCount: UInt32(instanceCount),
            firstVertex: UInt32(vertexStart),
            firstInstance: 0
        )
    }

    func endRenderPass() {
        renderEncoder.end()
    }
}

extension WGPURenderCommandEncoder {
    private func commitBindGroup() {
        guard let pipeline = currentPipeline else {
            // Pipeline not set yet, will commit when it's set
            return
        }
        
        bindGroupDirty = false
        
        // Get bind group layout from the pipeline (using auto-layout)
        let layout = pipeline.renderPipeline.getBindGroupLayout(groupIndex: 0)
        
        // Build entries matching the shader's expected bindings
        var entries: [BindGroupEntry] = []
        
        for (bindingSlot, texture) in textures {
            entries.append(BindGroupEntry(
                binding: UInt32(bindingSlot),
                textureView: texture.textureView
            ))
        }

        for (bindingSlot, sampler) in samplers {
            entries.append(BindGroupEntry(
                binding: UInt32(bindingSlot),
                sampler: sampler.wgpuSampler
            ))
        }

        // Add any additional uniform buffers
        for (bindGroupEntry, uniform) in uniformBuffers {
            entries.append(BindGroupEntry(
                binding: UInt32(bindGroupEntry.bindingSlot),
                buffer: uniform.buffer,
                offset: UInt64(uniform.offset),
                size: UInt64(uniform.buffer.size)
            ))
        }
        
        guard !entries.isEmpty else { return }
        
        // Create bind group using the pipeline's layout
        let bindGroup = device.createBindGroup(
            descriptor: BindGroupDescriptor(
                label: pipeline.descriptor.debugName + " Bind Group",
                layout: layout,
                entries: entries
            )
        )
        
        // Set bind group
        renderEncoder.setBindGroup(
            groupIndex: 0,
            group: bindGroup,
            dynamicOffsets: []
        )
    }
}

#endif
