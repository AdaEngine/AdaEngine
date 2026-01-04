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
    private var currentPipeline: WGPURenderPipeline?
    
    private var device: WebGPU.Device
    
    // Cache for bind groups - maps group index to bind group
    private var bindGroups: [Int: WebGPU.BindGroup] = [:]
    private var bindGroupLayouts: [Int: WebGPU.BindGroupLayout] = [:]
    
    // Resource caches for building bind groups
    private var vertexUniformBuffers: [Int: (buffer: WGPUUniformBuffer, offset: Int)] = [:]
    private var fragmentUniformBuffers: [Int: (buffer: WGPUUniformBuffer, offset: Int)] = [:]
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
    }

    func setVertexBuffer(_ buffer: UniformBuffer, offset: Int, index: Int) {
        guard let wgpuBuffer = buffer as? WGPUUniformBuffer else {
            fatalError("UniformBuffer is not a WGPUUniformBuffer")
        }
        vertexUniformBuffers[index] = (buffer: wgpuBuffer, offset: offset)
        updateBindGroup(groupIndex: 0)
    }

    func setVertexBuffer(_ buffer: VertexBuffer, offset: Int, index: Int) {
        guard let wgpuBuffer = buffer as? WGPUVertexBuffer else {
            fatalError("VertexBuffer is not a WGPUVertexBuffer")
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
            fatalError("UniformBuffer is not a WGPUUniformBuffer")
        }
        fragmentUniformBuffers[index] = (buffer: wgpuBuffer, offset: offset)
        updateBindGroup(groupIndex: 0)
    }

    func setVertexBuffer<T>(_ bufferData: BufferData<T>, offset: Int, index: Int) {
        guard let wgpuBuffer = bufferData.buffer as? WGPUBuffer else {
            fatalError("BufferData is not a WGPUBuffer")
        }

        renderEncoder.setVertexBuffer(
            slot: UInt32(index), 
            buffer: wgpuBuffer.buffer, 
            offset: UInt64(offset), 
            size: UInt64(wgpuBuffer.length)
        )
    }

    func setFragmentBuffer<T>(_ bufferData: BufferData<T>, offset: Int, index: Int) {
        // For generic buffers, we treat them as uniform buffers in bind group
        guard let wgpuBuffer = bufferData.buffer as? WGPUBuffer else {
            fatalError("BufferData is not a WGPUBuffer")
        }

        let uniform = WGPUUniformBuffer(buffer: wgpuBuffer.buffer, binding: index)
        uniform.label = bufferData.label
        fragmentUniformBuffers[index] = (buffer: uniform, offset: offset)
        updateBindGroup(groupIndex: 0)
    }

    func setIndexBuffer<T>(_ bufferData: BufferData<T>, indexFormat: IndexBufferFormat) {
        guard let wgpuBuffer = bufferData.buffer as? WGPUBuffer else {
            fatalError("BufferData is not a WGPUBuffer")
        }
        currentIndexBuffer = wgpuBuffer.buffer
        currentIndexType = indexFormat == .uInt32 ? .uint32 : .uint16
    }

    func setVertexBytes(_ bytes: UnsafeRawPointer, length: Int, index: Int) {
        guard let buffer = device.createBuffer(
            descriptor: BufferDescriptor(
                usage: [.vertex, .copyDst],
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
        unsafe renderEncoder.setVertexBuffer(
            slot: UInt32(index),
            buffer: buffer,
            offset: 0,
            size: UInt64(length)
        )
    }

    func setFragmentTexture(_ texture: Texture, index: Int) {
        guard let wgpuTexture = texture.gpuTexture as? WGPUGPUTexture else {
            fatalError("Texture's gpuTexture is not a WGPUGPUTexture")
        }
        textures[index] = wgpuTexture
        updateBindGroup(groupIndex: 0)
    }

    func setFragmentSamplerState(_ sampler: Sampler, index: Int) {
        guard let wgpuSampler = sampler as? WGPUSampler else {
            fatalError("Sampler is not a WGPUSampler")
        }
        samplers[index] = wgpuSampler
        updateBindGroup(groupIndex: 0)
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
        renderEncoder.drawIndexed(
            indexCount: UInt32(indexCount),
            instanceCount: UInt32(instanceCount),
            firstIndex: UInt32(indexBufferOffset / (currentIndexType == .uint32 ? 4 : 2)),
            baseVertex: 0,
            firstInstance: 0
        )
    }

    func draw(type: IndexPrimitive, vertexStart: Int, vertexCount: Int, instanceCount: Int) {
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
    private func updateBindGroup(groupIndex: Int) {
        // Collect all entries for this bind group
        var entries: [BindGroupEntry] = []
        var layoutEntries: [BindGroupLayoutEntry] = []
        var bindingIndex: UInt32 = 0

        // Add vertex uniform buffers
        for (_, (buffer, _)) in vertexUniformBuffers.sorted(by: { $0.key < $1.key }) {
            entries.append(BindGroupEntry(
                binding: bindingIndex,
                buffer: buffer.buffer,
                offset: 0
            ))
            layoutEntries.append(BindGroupLayoutEntry(
                binding: bindingIndex,
                visibility: [.vertex],
                buffer: BufferBindingLayout(
                    type: .uniform,
                    hasDynamicOffset: false
                )
            ))
            bindingIndex += 1
        }

        // Add fragment uniform buffers
        for (_, (buffer, _)) in fragmentUniformBuffers.sorted(by: { $0.key < $1.key }) {
            entries.append(BindGroupEntry(
                binding: bindingIndex,
                buffer: buffer.buffer,
                offset: 0
            ))
            layoutEntries.append(BindGroupLayoutEntry(
                binding: bindingIndex,
                visibility: [.fragment],
                buffer: BufferBindingLayout(
                    type: .uniform,
                    hasDynamicOffset: false
                )
            ))
            bindingIndex += 1
        }

        // Add textures and samplers (they should be paired)
        let maxTextureIndex = max(
            textures.keys.max() ?? -1,
            samplers.keys.max() ?? -1
        )
        for index in 0...maxTextureIndex {
            if let texture = textures[index] {
                entries.append(BindGroupEntry(
                    binding: bindingIndex,
                    textureView: texture.textureView
                ))
                layoutEntries.append(BindGroupLayoutEntry(
                    binding: bindingIndex,
                    visibility: [.fragment],
                    texture: TextureBindingLayout(
                        sampleType: .float,
                        viewDimension: .type2d,
                        multisampled: false
                    )
                ))
                bindingIndex += 1
            }

            if let sampler = samplers[index] {
                entries.append(BindGroupEntry(
                    binding: bindingIndex,
                    sampler: sampler.wgpuSampler
                ))
                layoutEntries.append(BindGroupLayoutEntry(
                    binding: bindingIndex,
                    visibility: [.fragment],
                    sampler: SamplerBindingLayout(type: .filtering)
                ))
                bindingIndex += 1
            }
        }

        guard !entries.isEmpty else { return }

        // Create or reuse bind group layout
        let layout: WebGPU.BindGroupLayout
        if let existingLayout = bindGroupLayouts[groupIndex] {
            layout = existingLayout
        } else {
            layout = device.createBindGroupLayout(
                descriptor: BindGroupLayoutDescriptor(
                    label: "BindGroupLayout_\(groupIndex)",
                    entries: layoutEntries
                )
            )
            bindGroupLayouts[groupIndex] = layout
        }

        // Create bind group
        let bindGroup = device.createBindGroup(
            descriptor: BindGroupDescriptor(
                label: "BindGroup_\(groupIndex)",
                layout: layout,
                entries: entries
            )
        )
        bindGroups[groupIndex] = bindGroup

        // Set bind group
        renderEncoder.setBindGroup(
            groupIndex: UInt32(groupIndex),
            group: bindGroup,
            dynamicOffsets: []
        )
    }
}

#endif
