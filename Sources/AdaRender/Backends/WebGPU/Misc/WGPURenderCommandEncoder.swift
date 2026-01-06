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
    
    // Resource caches for building bind groups - key is the shader binding index
    private var uniformBuffers: [Int: (buffer: WGPUUniformBuffer, offset: Int, visibility: WebGPU.ShaderStage)] = [:]
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

    func setVertexBuffer(_ buffer: UniformBuffer, offset: Int, index: Int) {
        guard let wgpuBuffer = buffer as? WGPUUniformBuffer else {
            fatalError("UniformBuffer is not a WGPUUniformBuffer")
        }
        // View uniform is typically at binding 1 in the shader (after texture at 0)
        let bindingIndex = 1  // AE_GlobalView is at binding 1
        uniformBuffers[bindingIndex] = (buffer: wgpuBuffer, offset: offset, visibility: [.vertex, .fragment])
        bindGroupDirty = true
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
        // Fragment uniforms go after vertex uniforms
        let bindingIndex = index + 2  // Offset by texture(0), uniform(1)
        uniformBuffers[bindingIndex] = (buffer: wgpuBuffer, offset: offset, visibility: .fragment)
        bindGroupDirty = true
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
        guard let wgpuBuffer = bufferData.buffer as? WGPUBuffer else {
            fatalError("BufferData is not a WGPUBuffer")
        }

        let uniform = WGPUUniformBuffer(buffer: wgpuBuffer.buffer, device: device, binding: index)
        uniform.label = bufferData.label
        let bindingIndex = index + 2
        uniformBuffers[bindingIndex] = (buffer: uniform, offset: offset, visibility: .fragment)
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
        renderEncoder.setVertexBuffer(
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
        // Texture at binding 0 (as per shader: layout (binding = 0) uniform sampler2D u_Texture)
        textures[index] = wgpuTexture
        bindGroupDirty = true
    }

    func setFragmentSamplerState(_ sampler: Sampler, index: Int) {
        guard let wgpuSampler = sampler as? WGPUSampler else {
            fatalError("Sampler is not a WGPUSampler")
        }
        samplers[index] = wgpuSampler
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
        
        // Binding 0: texture (sampler2D in GLSL becomes separate texture binding in WebGPU)
        if let texture = textures[0] {
            entries.append(BindGroupEntry(
                binding: 0,
                textureView: texture.textureView
            ))
        }
        
        // Binding 1: uniform buffer (AE_GlobalView)
        if let uniform = uniformBuffers[1] {
            entries.append(BindGroupEntry(
                binding: 1,
                buffer: uniform.buffer.buffer,
                offset: UInt64(uniform.offset),
                size: UInt64(uniform.buffer.length)
            ))
        }
        
        // Binding 2: sampler (sampler2D in GLSL becomes separate sampler binding in WebGPU)
        if let sampler = samplers[0] {
            entries.append(BindGroupEntry(
                binding: 2,
                sampler: sampler.wgpuSampler
            ))
        }
        
        // Add any additional uniform buffers
        for (bindingIndex, uniform) in uniformBuffers where bindingIndex > 1 {
            entries.append(BindGroupEntry(
                binding: UInt32(bindingIndex),
                buffer: uniform.buffer.buffer,
                offset: UInt64(uniform.offset),
                size: UInt64(uniform.buffer.length)
            ))
        }
        
        guard !entries.isEmpty else { return }
        
        // Create bind group using the pipeline's layout
        let bindGroup = device.createBindGroup(
            descriptor: BindGroupDescriptor(
                label: "SpriteBindGroup",
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
