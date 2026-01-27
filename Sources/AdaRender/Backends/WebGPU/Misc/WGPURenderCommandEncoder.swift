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

    struct BindGroupResources {
        var uniformBuffers: [Int: (buffer: WebGPU.Buffer, offset: Int, size: UInt64)] = [:]
        var textures: [Int: WGPUGPUTexture] = [:]
        var samplers: [Int: WGPUSampler] = [:]
    }

    private var bindGroupResources: [Int: BindGroupResources] = [:]

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
        
        // Save old pipeline before updating
        let oldPipeline = currentPipeline
        let pipelineChanged = oldPipeline !== wgpuPipeline
        
        renderEncoder.setPipeline(wgpuPipeline.renderPipeline)
        self.currentPipeline = wgpuPipeline
        
        // When switching between pipelines (not first pipeline in render pass),
        // clear textures and samplers but keep uniform buffers.
        // Different pipelines have different bind group layouts - some may not use
        // textures/samplers at all (e.g. Line Pipeline only uses uniform buffer).
        // Uniform buffers (like view uniform) are shared across pipelines.
        // 
        // We only clear if there WAS a previous pipeline - if oldPipeline was nil,
        // resources might have been set FOR this new pipeline before setRenderPipelineState.
        if pipelineChanged && oldPipeline != nil {
            for setIndex in bindGroupResources.keys {
                bindGroupResources[setIndex]?.textures.removeAll()
                bindGroupResources[setIndex]?.samplers.removeAll()
            }
        }
        
        // Always mark dirty when pipeline changes so bind group uses correct layout
        if pipelineChanged {
            bindGroupDirty = true
        }
        
        // NOTE: Do NOT call commitBindGroup() here!
        // Resources (textures, samplers) may be set AFTER the pipeline is set.
        // Bind groups should only be committed right before draw calls.
    }

    func setVertexBuffer(_ buffer: UniformBuffer, offset: Int, slot: Int) {
        guard let wgpuBuffer = buffer as? WGPUUniformBuffer else {
            fatalError("UniformBuffer is not a WGPUUniformBuffer")
        }
        updateBindGroupResources(setIndex: 0) { resources in
            resources.uniformBuffers[slot] = (
                buffer: wgpuBuffer.buffer,
                offset: offset,
                size: UInt64(wgpuBuffer.length)
            )
        }
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
        updateBindGroupResources(setIndex: 0) { resources in
            resources.uniformBuffers[slot] = (
                buffer: wgpuBuffer.buffer,
                offset: offset,
                size: UInt64(wgpuBuffer.length)
            )
        }
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

        updateBindGroupResources(setIndex: 0) { resources in
            resources.uniformBuffers[slot] = (
                buffer: wgpuBuffer.buffer,
                offset: offset,
                size: UInt64(wgpuBuffer.length)
            )
        }
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
        updateBindGroupResources(setIndex: 0) { resources in
            resources.uniformBuffers[slot] = (
                buffer: buffer,
                offset: 0,
                size: UInt64(length)
            )
        }
    }

    func setFragmentTexture(_ texture: Texture, slot: Int) {
        guard let wgpuTexture = texture.gpuTexture as? WGPUGPUTexture else {
            fatalError("Texture's gpuTexture is not a WGPUGPUTexture")
        }
        updateBindGroupResources(setIndex: 0) { resources in
            resources.textures[slot] = wgpuTexture
        }
    }

    func setFragmentSamplerState(_ sampler: Sampler, slot: Int) {
        guard let wgpuSampler = sampler as? WGPUSampler else {
            fatalError("Sampler is not a WGPUSampler")
        }
        updateBindGroupResources(setIndex: 0) { resources in
            resources.samplers[slot] = wgpuSampler
        }
    }

    func setResourceSet(_ resourceSet: RenderResourceSet, index: Int) {
        updateBindGroupResources(setIndex: index) { resources in
            for binding in resourceSet.bindings {
                switch binding.resource {
                case let .uniformBuffer(uniformBuffer, offset):
                    guard let wgpuBuffer = uniformBuffer as? WGPUUniformBuffer else {
                        fatalError("UniformBuffer is not a WGPUUniformBuffer")
                    }
                    resources.uniformBuffers[binding.binding] = (
                        buffer: wgpuBuffer.buffer,
                        offset: offset,
                        size: UInt64(wgpuBuffer.length)
                    )
                case let .texture(texture):
                    guard let wgpuTexture = texture.gpuTexture as? WGPUGPUTexture else {
                        fatalError("Texture's gpuTexture is not a WGPUGPUTexture")
                    }
                    resources.textures[binding.binding] = wgpuTexture
                case let .sampler(sampler):
                    guard let wgpuSampler = sampler as? WGPUSampler else {
                        fatalError("Sampler is not a WGPUSampler")
                    }
                    resources.samplers[binding.binding] = wgpuSampler
                }
            }
        }
    }

    private func updateBindGroupResources(setIndex: Int, update: (inout BindGroupResources) -> Void) {
        var resources = bindGroupResources[setIndex] ?? BindGroupResources()
        update(&resources)
        bindGroupResources[setIndex] = resources
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

        for setIndex in bindGroupResources.keys.sorted() {
            guard let resources = bindGroupResources[setIndex] else {
                continue
            }

            var entries: [BindGroupEntry] = []

            for (bindingSlot, texture) in resources.textures {
                entries.append(BindGroupEntry(
                    binding: UInt32(bindingSlot),
                    textureView: texture.textureView
                ))
            }

            for (bindingSlot, sampler) in resources.samplers {
                entries.append(BindGroupEntry(
                    binding: UInt32(bindingSlot),
                    sampler: sampler.wgpuSampler
                ))
            }

            for (bindingSlot, uniform) in resources.uniformBuffers {
                entries.append(BindGroupEntry(
                    binding: UInt32(bindingSlot),
                    buffer: uniform.buffer,
                    offset: UInt64(uniform.offset),
                    size: uniform.size
                ))
            }

            guard !entries.isEmpty else { continue }

            // Get bind group layout - this will fail if the pipeline is invalid
            // The layout will be null/invalid if the pipeline creation failed
            let layout = pipeline.renderPipeline.getBindGroupLayout(groupIndex: UInt32(setIndex))
            let bindGroup = device.createBindGroup(
                descriptor: BindGroupDescriptor(
                    label: pipeline.descriptor.debugName + " Bind Group \(setIndex)",
                    layout: layout,
                    entries: entries
                )
            )

            renderEncoder.setBindGroup(
                groupIndex: UInt32(setIndex),
                group: bindGroup,
                dynamicOffsets: []
            )
        }
    }

}

#endif
