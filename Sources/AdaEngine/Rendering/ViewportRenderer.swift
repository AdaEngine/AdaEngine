//
//  ViewportRenderer.swift
//  AdaEngine
//
//  Created by v.prusakov on 1/28/23.
//

class ViewportRenderer {
    
    static let shared = ViewportRenderer()
    
    private let renderPipeline: RenderPipeline
    private let quadIndexArray: RID
    private let quadVertexBuffer: VertexBuffer
    private let viewportUniformSet: UniformBufferSet
    
    private struct ViewportUniform {
        let viewTransform: Transform3D
    }
    
    // FIXME: Remove it
    private let greenTexture: Texture2D
    
    private init() {
        let device = RenderEngine.shared
        
        let shaderDesc = ShaderDescriptor(
            shaderName: "viewport_composer",
            vertexFunction: "vpcomposer_vertex",
            fragmentFunction: "vpcomposer_fragment"
        )
        
        let samplerDesc = SamplerDescriptor(minFilter: .linear, magFilter: .linear, mipFilter: .linear)
        let sampler = device.makeSampler(from: samplerDesc)
        
        let shader = device.makeShader(from: shaderDesc)
        var piplineDesc = RenderPipelineDescriptor(shader: shader)
        piplineDesc.debugName = "Viewport Composer Pipeline"
        piplineDesc.sampler = sampler
        
        piplineDesc.vertexDescriptor.attributes.append([
            .attribute(.vector3, name: "position"),
            .attribute(.vector2, name: "textureCoordinate")
        ])
        
        piplineDesc.vertexDescriptor.layouts[0].stride = MemoryLayout<Quad>.stride
        piplineDesc.colorAttachments = [
            ColorAttachmentDescriptor(
                format: .bgra8,
                isBlendingEnabled: false
            )
        ]
        
        struct Quad {
            var position: Vector3
            var textureCoordinate: Vector2
        }
        
        var quadData = [
            Quad(position: [-1, -1, 0.0], textureCoordinate: [0, 1]),
            Quad(position: [1, -1, 0.0], textureCoordinate: [1, 1]),
            Quad(position: [1, 1, 0.0], textureCoordinate: [1, 0]),
            Quad(position: [-1, 1, 0.0], textureCoordinate: [0, 0])
        ]
        
        var quadIndices: [UInt32] = [0, 1, 2, 2, 3, 0]
        
        let quadIndexBuffer = device.makeIndexBuffer(
            index: 0,
            format: .uInt32,
            bytes: &quadIndices,
            length: 6 * MemoryLayout<UInt32>.size
        )
        
        self.quadIndexArray = device.makeIndexArray(
            indexBuffer: quadIndexBuffer,
            indexOffset: 0,
            indexCount: quadIndices.count
        )
        
        self.quadVertexBuffer = device.makeVertexBuffer(
            length: MemoryLayout<Quad>.size * quadData.count,
            binding: 0
        )
        self.quadVertexBuffer.setData(&quadData, byteCount: MemoryLayout<Quad>.size * quadData.count)
        
        self.viewportUniformSet = device.makeUniformBufferSet()
        self.viewportUniformSet.initBuffers(for: ViewportUniform.self, binding: BufferIndex.baseUniform, set: 0)
        
        self.renderPipeline = device.makeRenderPipeline(from: piplineDesc)
        
        let image = Image(width: 1, height: 1, color: .green)
        self.greenTexture = Texture2D(image: image)
    }
    
    // MARK: Methods
    
    // TODO: Add statistics how long viewports renders
    func beginFrame() {
        
    }
    
    func endFrame() {
        
    }
    
    func renderViewports() {
        let viewports = ViewportStorage.getViewports()
        
        for viewport in viewports {
            
            guard let window = viewport.window, viewport.isVisible else {
                continue
            }
            
            let frameIndex = RenderEngine.shared.currentFrameIndex
            let buffer = self.viewportUniformSet.getBuffer(
                binding: BufferIndex.baseUniform,
                set: 0,
                frameIndex: frameIndex
            )
            buffer.setData(ViewportUniform(viewTransform: .identity))
            
            let draw = RenderEngine.shared.beginDraw(for: window.id, clearColor: .black)
            draw.setDebugName("Rendering viewport \(viewport.viewportRid!)")
            
            draw.appendUniformBuffer(buffer)
            draw.bindIndexArray(self.quadIndexArray)
            draw.appendVertexBuffer(self.quadVertexBuffer)
            draw.bindTexture(viewport.renderTargetTexture, at: 0)
//            draw.bindTexture(self.greenTexture, at: 0)
            draw.bindRenderPipeline(self.renderPipeline)
            
            RenderEngine.shared.draw(draw, indexCount: 6, instancesCount: 1)
            RenderEngine.shared.endDrawList(draw)
        }
    }
}

/// Contains information about all viewports in the engine. Also create and store a framebuffer.
class ViewportStorage {
    
    private static var viewports: ResourceHashMap<WeakBox<Viewport>> = [:]
    private static var framebuffers: ResourceHashMap<Framebuffer> = [:]
    
    static func addViewport(_ viewport: Viewport) -> RID {
        viewports.setValue(WeakBox(value: viewport))
    }
    
    static func removeViewport(_ viewport: Viewport) {
        self.viewports[viewport.viewportRid] = nil
        self.framebuffers[viewport.viewportRid] = nil
    }
    
    static func getViewports() -> [Viewport] {
        return self.viewports.values.compactMap { $0.value }
    }
    
    static func viewportUpdateSize(_ newSize: Size, viewport: Viewport) {
        if let frambuffer = self.framebuffers[viewport.viewportRid] {
            frambuffer.resize(to: newSize)
            
            return
        }
        
        var descriptor = FramebufferDescriptor()
        descriptor.scale = viewport.window?.screen?.scale ?? 1.0
        descriptor.width = Int(newSize.width)
        descriptor.height = Int(newSize.height)
        
        descriptor.attachments = [
            FramebufferAttachmentDescriptor(format: .bgra8)
        ]
        
        let framebuffer = RenderEngine.shared.makeFramebuffer(from: descriptor)
        self.framebuffers.setValue(framebuffer, forKey: viewport.viewportRid)
    }
    
    static func getRenderTexture(for viewport: Viewport) -> Texture2D? {
        return self.framebuffers[viewport.viewportRid]?.attachments.first(where: {
            return $0.usage.contains(.colorAttachment)
        })?.texture
    }
    
    static func getFramebuffer(for viewport: Viewport) -> Framebuffer? {
        return self.framebuffers[viewport.viewportRid]
    }
}
