//
//  ViewportRenderer.swift
//  AdaEngine
//
//  Created by v.prusakov on 1/28/23.
//

class ViewportRenderer {
    
    static let shared = ViewportRenderer()
    
    var viewports = ResourceHashMap<Viewport>()
    
    let renderPipeline: RenderPipeline
    let quadIndexArray: RID
    let viewportUniform: RID
    let quadVertexArray: RID
    let quadVertexBuffer: RID
    
    struct Quad {
        var position: Vector3
        var textureCoordinate: Vector2
    }
    
    struct ViewportUniform {
        let viewTransform: Transform3D
    }
    
    // FIXME: Remove it
    let greenTexture: Texture2D
    
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
            offset: 0,
            index: 0,
            bytes: &quadData,
            length: MemoryLayout<Quad>.size * quadData.count
        )
        
        self.quadVertexArray = device.makeVertexArray(vertexBuffers: [quadVertexBuffer], vertexCount: quadData.count)
        self.viewportUniform = device.makeUniform(ViewportUniform.self, count: 1, offset: 0, options: .storageShared)
        self.renderPipeline = device.makeRenderPipeline(from: piplineDesc)
        
        let image = Image(width: 1, height: 1, color: .green)
        self.greenTexture = Texture2D(image: image)
    }
    
    // MARK: Methods
    
    func addViewport(_ viewport: Viewport) -> RID {
        viewports.setValue(viewport)
    }
    
    func removeViewport(_ viewport: Viewport) {
        viewports[viewport.viewportRid] = nil
    }
    
    func beginFrame() {
        
    }
    
    func endFrame() {
        
    }
    
    func renderViewports() {
        let activeViewports = self.viewports.map { $0.value }
        
        for viewport in activeViewports {
            
            guard let window = viewport.window, viewport.isVisible else {
                continue
            }
            
            let scale = window.screen?.scale ?? 1.0
            
            let uniform = ViewportUniform(viewTransform: .identity)
            RenderEngine.shared.updateUniform(self.viewportUniform, value: uniform, count: 1)
            
            let draw = RenderEngine.shared.beginDraw(for: window.id)
            draw.setDebugName("Rendering viewport \(viewport.viewportRid!)")
            
            draw.bindUniformSet(self.viewportUniform, at: BufferIndex.baseUniform)
            draw.bindIndexArray(self.quadIndexArray)
            draw.bindVertexArray(self.quadVertexArray)
            draw.bindTexture(viewport.renderTexture, at: 0)
//            draw.bindTexture(self.greenTexture, at: 0)
            draw.bindRenderPipeline(self.renderPipeline)
            
            RenderEngine.shared.draw(draw, indexCount: 6, instancesCount: 1)
            RenderEngine.shared.endDrawList(draw)
        }
    }
}
