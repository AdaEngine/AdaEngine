//
//  RenderEngine2D.swift
//  
//
//  Created by v.prusakov on 5/10/22.
//

import Math

// TODO: (Vlad) Fix depth stencil
// TODO: (Vlad) Store render pass 
public class RenderEngine2D {
    
    enum Bindings {
        static let cameraUniform: Int = 1
    }
    
    static var minimumZIndex = -4096
    
    static var maximumZIndex = 4096
    
    private var uniform: Uniform = Uniform()
    
    struct Uniform {
        var viewProjection: Transform3D = .identity
    }
    
    public static let `default` = RenderEngine2D()
    
    private var uniformSet: UniformBufferSet
    
    struct Data<V> {
        var vertexBuffer: VertexBuffer
        var vertices: [V] = []
        var indeciesCount: Int
        var indexArray: RID
        let renderPipeline: RenderPipeline
    }
    
    private var circleData: Data<CircleVertexData>
    private var quadData: Data<QuadVertexData>
    private var lineData: Data<LineVertexData>
    private var quadPosition: [Vector4] = []
    
    private var textureSlots: [Texture2D?]
    private var textureSlotIndex = 1
    private let whiteTexture: Texture2D
    
    private static var maxQuads = 20_000
    private static var maxVerticies = maxQuads * 4
    private static var maxIndecies = maxQuads * 6
    
    private static let maxLines = 2000
    private static let maxLineVertices = maxLines * 2
    private static let maxLineIndices = maxLines * 6
    
    // TODO: (Vlad) Maybe we should split this code
    // swiftlint:disable:next function_body_length
    init() {
        let device = RenderEngine.shared
        
        self.uniformSet = device.makeUniformBufferSet()
        self.uniformSet.initBuffers(for: Uniform.self, binding: Bindings.cameraUniform, set: 0)
        
        self.quadPosition = [
            [-0.5, -0.5,  0.0, 1.0],
            [-0.5,  0.5,  0.0, 1.0],
            [ 0.5,  0.5,  0.0, 1.0],
            [ 0.5, -0.5,  0.0, 1.0]
        ]
        
        var quadIndices = [UInt32].init(repeating: 0, count: Self.maxIndecies)
        
        var offset: UInt32 = 0
        for index in stride(from: 0, to: Self.maxIndecies, by: 6) {
            quadIndices[index + 0] = offset + 0
            quadIndices[index + 1] = offset + 1
            quadIndices[index + 2] = offset + 2
            
            quadIndices[index + 3] = offset + 2
            quadIndices[index + 4] = offset + 3
            quadIndices[index + 5] = offset + 0
            
            offset += 4
        }
        
        let quadIndexBuffer = device.makeIndexBuffer(
            index: 0,
            format: .uInt32,
            bytes: &quadIndices,
            length: Self.maxIndecies
        )
        
        // Create an empty white texture
        // because if user don't pass texture to render, we will use this white texture
        let image = Image(width: 1, height: 1, color: .white)
        self.whiteTexture = Texture2D(image: image)
        self.textureSlots = [Texture2D?].init(repeating: nil, count: 32)
        self.textureSlots[0] = self.whiteTexture
        
        let indexArray = device.makeIndexArray(indexBuffer: quadIndexBuffer, indexOffset: 0, indexCount: Self.maxIndecies)
        
        var stencilDesc = StencilOperationDescriptor()
        stencilDesc.fail = .zero
        stencilDesc.pass = .zero
        stencilDesc.depthFail = .zero
        stencilDesc.compare = .always
        
        var depthStencilDesc = DepthStencilDescriptor()
        depthStencilDesc.isEnableStencil = true
        depthStencilDesc.stencilOperationDescriptor = stencilDesc
        
        depthStencilDesc.isDepthTestEnabled = true
        depthStencilDesc.isDepthWriteEnabled = true
        depthStencilDesc.depthCompareOperator = .less
        
        var samplerDesc = SamplerDescriptor()
        samplerDesc.magFilter = .nearest
        let sampler = device.makeSampler(from: samplerDesc)
        
        // Circle
        
        let circleShaderDesc = ShaderDescriptor(
            shaderName: "circle",
            vertexFunction: "circle_vertex",
            fragmentFunction: "circle_fragment"
        )
        
        let circleShader: Shader = device.makeShader(from: circleShaderDesc)
        
        var piplineDesc = RenderPipelineDescriptor(shader: circleShader)
        piplineDesc.debugName = "Circle Pipeline"
        piplineDesc.backfaceCulling = false
//        piplineDesc.depthStencilDescriptor = depthStencilDesc
        piplineDesc.sampler = sampler
        
        piplineDesc.vertexDescriptor.attributes.append([
            .attribute(.vector4, name: "worldPosition"),
            .attribute(.vector4, name: "localPosition"),
            .attribute(.float, name: "thickness"),
            .attribute(.float, name: "fade"),
            .attribute(.vector4, name: "color"),
        ])
        
        piplineDesc.vertexDescriptor.layouts[0].stride = MemoryLayout<CircleVertexData>.stride
        
        var attachment = ColorAttachmentDescriptor(format: .bgra8)
        attachment.isBlendingEnabled = true
        
        piplineDesc.colorAttachments = [attachment]
        
        let circlePipeline = device.makeRenderPipeline(from: piplineDesc)
        
        let circleVertexBuffer = device.makeVertexBuffer(
            length: MemoryLayout<CircleVertexData>.stride * Self.maxVerticies,
            binding: 0
        )
        
        self.circleData = Data<CircleVertexData>(
            vertexBuffer: circleVertexBuffer,
            vertices: [],
            indeciesCount: 0,
            indexArray: indexArray,
            renderPipeline: circlePipeline
        )
        
        // Quads
        
        piplineDesc.vertexDescriptor.reset()
        
        piplineDesc.debugName = "Quad Pipline"
        
        let quadShaderDesc = ShaderDescriptor(
            shaderName: "quad",
            vertexFunction: "quad_vertex",
            fragmentFunction: "quad_fragment"
        )
        
        let quadShader: Shader = device.makeShader(from: quadShaderDesc)
        
        piplineDesc.shader = quadShader
        
        piplineDesc.vertexDescriptor.attributes.append([
            .attribute(.vector4, name: "position"),
            .attribute(.vector4, name: "color"),
            .attribute(.vector2, name: "textureCoordinate"),
            .attribute(.int, name: "textureIndex"),
        ])
        
        piplineDesc.vertexDescriptor.layouts[0].stride = MemoryLayout<QuadVertexData>.stride
        
        let quadPipeline = device.makeRenderPipeline(from: piplineDesc)
        
        let quadVertexBuffer = device.makeVertexBuffer(
            length: MemoryLayout<QuadVertexData>.stride * Self.maxVerticies,
            binding: 0
        )
        
        self.quadData =  Data<QuadVertexData>(
            vertexBuffer: quadVertexBuffer,
            vertices: [],
            indeciesCount: 0,
            indexArray: indexArray,
            renderPipeline: quadPipeline
        )
        
        // Lines
        
        piplineDesc.vertexDescriptor.reset()
        
        piplineDesc.debugName = "Lines Pipeline"
        
        let lineShaderDesc = ShaderDescriptor(
            shaderName: "line",
            vertexFunction: "line_vertex",
            fragmentFunction: "line_fragment"
        )
        
        let lineShader: Shader = device.makeShader(from: lineShaderDesc)
        piplineDesc.shader = lineShader
        
        piplineDesc.vertexDescriptor.attributes.append([
            .attribute(.vector3, name: "position"),
            .attribute(.vector4, name: "color"),
            .attribute(.float, name: "lineWidth"),
        ])
        
        piplineDesc.vertexDescriptor.layouts[0].stride = MemoryLayout<LineVertexData>.stride
        
        let linesPipeline = device.makeRenderPipeline(from: piplineDesc)
        
        let linesVertexBuffer = device.makeVertexBuffer(
            length: MemoryLayout<LineVertexData>.stride * Self.maxLineVertices,
            binding: 0
        )
        
        var buffer: [Int32] = [Int32].init(repeating: 0, count: Self.maxLineIndices)
        
        for i in 0 ..< Self.maxLineIndices {
            buffer[i] = Int32(i)
        }
        
        let indexBuffer = device.makeIndexBuffer(
            index: 0,
            format: .uInt32,
            bytes: &buffer,
            length: Self.maxLineIndices
        )
        
        let linesIndexArray = device.makeIndexArray(indexBuffer: indexBuffer, indexOffset: 0, indexCount: Self.maxLineIndices)
        
        self.lineData =  Data<LineVertexData>(
            vertexBuffer: linesVertexBuffer,
            vertices: [],
            indeciesCount: 0,
            indexArray: linesIndexArray,
            renderPipeline: linesPipeline
        )
    }
    
    public func beginContext(for viewport: Viewport, viewTransform: Transform3D) -> DrawContext {
        let frameIndex = RenderEngine.shared.currentFrameIndex
        
        let uniform = self.uniformSet.getBuffer(binding: Bindings.cameraUniform, set: 0, frameIndex: frameIndex)
        uniform.setData(Uniform(viewProjection: viewTransform))

        let window = viewport.window!
        
        let currentDraw = RenderEngine.shared.beginDraw(for: window.id, clearColor: .black)
        let context = DrawContext(currentDraw: currentDraw, renderEngine: self, frameIndex: frameIndex)
        context.startBatch()
        return context
    }
    
    public func beginContext(for camera: Camera) -> DrawContext {
        let data = camera.makeCameraData()
        
        let frameIndex = RenderEngine.shared.currentFrameIndex
        
        let uniform = self.uniformSet.getBuffer(binding: Bindings.cameraUniform, set: 0, frameIndex: frameIndex)
        uniform.setData(Uniform(viewProjection: data.viewProjection))
        
        let viewport = camera.viewport!
        
        guard let framebuffer = ViewportStorage.getFramebuffer(for: viewport) else {
            fatalError("Viewport doesn't has a framebuffer")
        }
        
        let currentDraw = RenderEngine.shared.beginDraw(to: framebuffer)
        
        let context = DrawContext(currentDraw: currentDraw, renderEngine: self, frameIndex: frameIndex)
        context.startBatch()
        return context
    }
}

extension RenderEngine2D {
    public class DrawContext {
        
        let currentDraw: DrawList
        
        private var fillColor: Color = .clear
        
        private var lineWidth: Float = 1
        
        private let renderEngine: RenderEngine2D
        private let frameIndex: Int
        
        init(currentDraw: DrawList, renderEngine: RenderEngine2D, frameIndex: Int) {
            self.currentDraw = currentDraw
            self.renderEngine = renderEngine
            self.frameIndex = frameIndex
        }
        
        public func drawQuad(position: Vector3, size: Vector2, texture: Texture2D? = nil, color: Color) {
            let transform = Transform3D(translation: position) * Transform3D(scale: Vector3(size, 1))
            self.drawQuad(transform: transform, texture: texture, color: color)
        }
        
        public func drawQuad(transform: Transform3D, texture: Texture2D? = nil, color: Color) {
            
            if self.renderEngine.quadData.indeciesCount >= RenderEngine2D.maxIndecies {
                self.nextBatch()
            }
            
            // Flush all data if textures count more than 32
            if self.renderEngine.textureSlotIndex >= 31 {
                self.nextBatch()
                self.renderEngine.textureSlots = [Texture2D?].init(repeating: nil, count: 32)
                self.renderEngine.textureSlots[0] = self.renderEngine.whiteTexture
                self.renderEngine.textureSlotIndex = 1
            }
            
            // Select a texture index for draw
            
            let textureIndex: Int
            
            if let texture = texture {
                if let index = self.renderEngine.textureSlots.firstIndex(where: { $0 === texture }) {
                    textureIndex = index
                } else {
                    self.renderEngine.textureSlots[self.renderEngine.textureSlotIndex] = texture
                    textureIndex = self.renderEngine.textureSlotIndex
                    self.renderEngine.textureSlotIndex += 1
                }
            } else {
                // for white texture
                textureIndex = 0
            }
            
            let texture = self.renderEngine.textureSlots[textureIndex]
            
            for index in 0 ..< renderEngine.quadPosition.count {
                let data = QuadVertexData(
                    position: transform * renderEngine.quadPosition[index],
                    color: color,
                    textureCoordinate: texture!.textureCoordinates[index],
                    textureIndex: textureIndex
                )
                
                self.renderEngine.quadData.vertices.append(data)
            }
            
            self.renderEngine.quadData.indeciesCount += 6
        }
        
        public func setDebugName(_ name: String) {
            self.currentDraw.setDebugName(name)
        }
        
        public func setLineWidth(_ width: Float) {
            self.currentDraw.setLineWidth(width)
        }
        
        public func drawCircle(
            position: Vector3,
            rotation: Vector3,
            radius: Float,
            thickness: Float,
            fade: Float,
            color: Color
        ) {
            let transform = Transform3D(translation: position)
            * Transform3D(quat: Quat(axis: [1, 0, 0], angle: rotation.x))
            * Transform3D(quat: Quat(axis: [0, 1, 0], angle: rotation.y))
            * Transform3D(quat: Quat(axis: [0, 0, 1], angle: rotation.z))
            * Transform3D(scale: Vector3(radius))
            
            self.drawCircle(transform: transform, thickness: thickness, fade: fade, color: color)
        }
        
        public func drawCircle(
            transform: Transform3D,
            thickness: Float,
            fade: Float,
            color: Color
        ) {
            if self.renderEngine.circleData.indeciesCount >= RenderEngine2D.maxIndecies {
                self.nextBatch()
            }
            
            for quad in renderEngine.quadPosition {
                let data = CircleVertexData(
                    worldPosition: quad * transform,
                    localPosition: quad * 2,
                    thickness: thickness,
                    fade: fade,
                    color: color
                )
                
                self.renderEngine.circleData.vertices.append(data)
            }
            
            self.renderEngine.circleData.indeciesCount += 6
        }
        
        public func drawLine(start: Vector3, end: Vector3, color: Color) {
            if self.renderEngine.lineData.indeciesCount >= RenderEngine2D.maxLineIndices {
                self.nextBatch()
            }
            
            let startData = LineVertexData(
                position: start,
                color: color,
                lineWidth: lineWidth
            )
            
            let endData = LineVertexData(
                position: end,
                color: color,
                lineWidth: lineWidth
            )
            
            self.renderEngine.lineData.vertices.append(startData)
            self.renderEngine.lineData.vertices.append(endData)
            
            self.renderEngine.lineData.indeciesCount += 2
        }
        
        /// - Note: When you commited context, you can't modify it. Your drawing will flush and free immidiatly.
        public func commitContext() {
            self.flush()
            
            self.clearContext()
            
            RenderEngine.shared.endDrawList(self.currentDraw)
        }
        
        public func clearContext() {
            self.renderEngine.uniform.viewProjection = .identity // FIXME: (Vlad) Should store in draw contexrt
        }
        
        public func setTriangleFillMode(_ mode: TriangleFillMode) {
            self.currentDraw.bindTriangleFillMode(mode)
        }
        
        func nextBatch() {
            self.flush()
            self.startBatch()
        }
        
        func startBatch() {
            // TODO: (Vlad) Should store in draw context
            self.renderEngine.circleData.vertices.removeAll(keepingCapacity: true)
            self.renderEngine.circleData.indeciesCount = 0
            
            self.renderEngine.quadData.vertices.removeAll(keepingCapacity: true)
            self.renderEngine.quadData.indeciesCount = 0
            
            self.renderEngine.lineData.vertices.removeAll(keepingCapacity: true)
            self.renderEngine.lineData.indeciesCount = 0
        }
        
        public func flush() {
            let buffer = self.renderEngine.uniformSet.getBuffer(
                binding: Bindings.cameraUniform,
                set: 0,
                frameIndex: self.frameIndex
            )
            
            self.currentDraw.appendUniformBuffer(buffer)
            
            self.flush(for: self.renderEngine.quadData, currentDraw: currentDraw)
            self.flush(for: self.renderEngine.lineData, indexPrimitive: .line, currentDraw: currentDraw)
            self.flush(for: self.renderEngine.circleData, currentDraw: currentDraw)
        }
        
        private func flush<D>(for data: Data<D>, indexPrimitive: IndexPrimitive = .triangle, currentDraw: DrawList) {
            if data.indeciesCount == 0 {
                return
            }
            
            var verticies = data.vertices
            
            let textures = self.renderEngine.textureSlots[0..<self.renderEngine.textureSlotIndex].compactMap { $0 }
            
            for (index, texture) in textures.enumerated() {
                currentDraw.bindTexture(texture, at: index)
            }
            
            data.vertexBuffer.setData(&verticies, byteCount: verticies.count * MemoryLayout<D>.stride)
            
            currentDraw.appendVertexBuffer(data.vertexBuffer)
            currentDraw.bindRenderPipeline(data.renderPipeline)
            currentDraw.bindIndexArray(data.indexArray)
            currentDraw.bindIndexPrimitive(indexPrimitive)
            
            RenderEngine.shared.draw(currentDraw, indexCount: data.indeciesCount, instancesCount: 1)
        }
        
    }
}

// MARK: - Utilities

fileprivate extension RenderEngine2D {
    
    struct CircleVertexData {
        let worldPosition: Vector4
        let localPosition: Vector4
        let thickness: Float
        let fade: Float
        let color: Color
    }
    
    struct QuadVertexData {
        let position: Vector4
        let color: Color
        let textureCoordinate: Vector2
        let textureIndex: Int
    }
    
    struct LineVertexData {
        let position: Vector3
        let color: Color
        let lineWidth: Float
    }
}
