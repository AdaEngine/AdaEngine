//
//  RenderEngine2D.swift
//  
//
//  Created by v.prusakov on 5/10/22.
//

import Math

public class RenderEngine2D {
    
    private var uniform: Uniform = Uniform()
    
    struct Uniform {
        var viewProjection: Transform3D = .identity
    }
    
    private var uniformRid: RID
    
    struct Data<V> {
        var vertexArray: RID
        var vertexBuffer: RID
        var vertices: [V] = []
        var indeciesCount: Int
        var indexArray: RID
        var piplineState: RID
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
    
    private static let maxLines = 2000;
    private static let maxLineVertices = maxLines * 2;
    private static let maxLineIndices = maxLines * 6;
    
    init() {
        let device = RenderEngine.shared
        
        self.uniformRid = device.makeUniform(Uniform.self, count: 1, offset: 0, options: .storageShared)
        
        self.quadPosition = [
            [-0.5, -0.5,  0.0, 1.0],
            [ 0.5, -0.5,  0.0, 1.0],
            [ 0.5,  0.5,  0.0, 1.0],
            [-0.5,  0.5,  0.0, 1.0]
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
            offset: 0,
            index: 0,
            format: .uInt32,
            bytes: &quadIndices,
            length: Self.maxIndecies
        )
        
        // Create an empty white texture
        // because if user don't pass texture to render, we will use this white texture
        let image = Image(width: 1, height: 1, color: .white)
        self.whiteTexture = Texture2D(from: image)
        self.textureSlots = [Texture2D?].init(repeating: nil, count: 32)
        self.textureSlots[0] = self.whiteTexture
        
        let indexArray = device.makeIndexArray(indexBuffer: quadIndexBuffer, indexOffset: 0, indexCount: Self.maxIndecies)
        
        self.circleData = Self.makeCircleData(indexArray: indexArray)
        self.quadData = Self.makeQuadData(indexArray: indexArray)
        self.lineData = Self.makeLineData()
    }
    
    public func beginContext(for window: Window.ID, viewTransform: Transform3D) -> DrawContext {
        let uni = Uniform(viewProjection: viewTransform)
        RenderEngine.shared.updateUniform(self.uniformRid, value: uni, count: 1)
        
        let currentDraw = RenderEngine.shared.beginDraw(for: window)
        let context = DrawContext(currentDraw: currentDraw, window: window, renderEngine: self)
        context.startBatch()
        return context
    }
    
    public func beginContext(for window: Window.ID, camera: Camera) -> DrawContext {
        let data = camera.makeCameraData()
        let uni = Uniform(viewProjection: camera.transform.matrix * data.viewProjection)
        RenderEngine.shared.updateUniform(self.uniformRid, value: uni, count: 1)
        
        let currentDraw = RenderEngine.shared.beginDraw(for: window)
        
        let context = DrawContext(currentDraw: currentDraw, window: window, renderEngine: self)
        context.startBatch()
        return context
    }
}

extension RenderEngine2D {
    public class DrawContext {
        let currentDraw: RID
        let window: Window.ID
        
        private var fillColor: Color = .clear
        
        private var lineWidth: Float = 1
        
        private var triangleFillMode: TriangleFillMode = .fill
        private let renderEngine: RenderEngine2D
        
        init(currentDraw: RID, window: Window.ID, renderEngine: RenderEngine2D) {
            self.currentDraw = currentDraw
            self.window = window
            self.renderEngine = renderEngine
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
                self.renderEngine.textureSlots.removeAll(keepingCapacity: true)
                self.renderEngine.textureSlots[0] = self.renderEngine.whiteTexture
                self.renderEngine.textureSlotIndex = 1
            }
            
            // Select a texture index for draw
            
            let textureIndex: Int
            
            if let texture = texture {
                if let index = self.renderEngine.textureSlots.firstIndex(where: { $0 == texture }) {
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
                    position: renderEngine.quadPosition[index] * transform,
                    color: color,
                    textureCoordinate: texture!.textureCoordinates[index],
                    textureIndex: textureIndex
                )
                
                self.renderEngine.quadData.vertices.append(data)
            }
            
            self.renderEngine.quadData.indeciesCount += 6
        }
        
        public func setDebugName(_ name: String) {
            RenderEngine.shared.bindDebugName(name: name, forDraw: self.currentDraw)
        }
        
        public func setLineWidth(_ width: Float) {
            self.lineWidth = width
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
        
        public func commitContext() {
            self.flush()
            
            RenderEngine.shared.drawEnd(self.currentDraw)
            
            self.clearContext()
        }
        
        public func clearContext() {
            self.renderEngine.uniform.viewProjection = .identity // FIXME(Vlad): Should store in draw contexrt
            self.triangleFillMode = .fill
            self.lineWidth = 1
        }
        
        public func setTriangleFillMode(_ mode: TriangleFillMode) {
            self.triangleFillMode = mode
        }
        
        func nextBatch() {
            self.flush()
            self.startBatch()
        }
        
        func startBatch() {
            // TODO: Should store in draw context
            self.renderEngine.circleData.vertices.removeAll(keepingCapacity: true)
            self.renderEngine.circleData.indeciesCount = 0
            
            self.renderEngine.quadData.vertices.removeAll(keepingCapacity: true)
            self.renderEngine.quadData.indeciesCount = 0
            
            self.renderEngine.lineData.vertices.removeAll(keepingCapacity: true)
            self.renderEngine.lineData.indeciesCount = 0
        }
        
        public func flush() {
            let device = RenderEngine.shared
            
            device.bindUniformSet(currentDraw, uniformSet: self.renderEngine.uniformRid, at: BufferIndex.baseUniform)
            device.bindTriangleFillMode(currentDraw, mode: self.triangleFillMode)
            
            self.flush(for: self.renderEngine.quadData, currentDraw: currentDraw)
            self.flush(for: self.renderEngine.lineData, indexPrimitive: .line, currentDraw: currentDraw)
            self.flush(for: self.renderEngine.circleData, currentDraw: currentDraw)
        }
        
        private func flush<D>(for data: Data<D>, indexPrimitive: IndexPrimitive = .triangle, currentDraw: RID) {
            if data.indeciesCount == 0 {
                return
            }
            
            let verticies = data.vertices
            
            let textures = self.renderEngine.textureSlots[0..<self.renderEngine.textureSlotIndex].compactMap { $0 }
            
            for (index, texture) in textures.enumerated() {
                RenderEngine.shared.bindTexture(currentDraw, texture: texture.rid, at: index)
            }
            
            RenderEngine.shared.setVertexBufferData(
                data.vertexBuffer,
                bytes: verticies,
                length: verticies.count * MemoryLayout<D>.stride
            )
            
            RenderEngine.shared.bindVertexArray(currentDraw, vertexArray: data.vertexArray)
            RenderEngine.shared.bindRenderState(currentDraw, renderPassId: data.piplineState)
            RenderEngine.shared.bindIndexArray(currentDraw, indexArray: data.indexArray)
            RenderEngine.shared.bindIndexPrimitive(currentDraw, mode: indexPrimitive)
            
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
    
    private static func makeCircleData(indexArray: RID) -> Data<CircleVertexData> {
        let device = RenderEngine.shared
        
        var shaderDescriptor = ShaderDescriptor(
            shaderName: "circle",
            vertexFunction: "circle_vertex",
            fragmentFunction: "circle_fragment"
        )
        
        var vertDescriptor = shaderDescriptor.vertexDescriptor
        
        vertDescriptor.attributes.append([
            .attribute(.vector4, name: "worldPosition"),
            .attribute(.vector4, name: "localPosition"),
            .attribute(.float, name: "thickness"),
            .attribute(.float, name: "fade"),
            .attribute(.vector4, name: "color"),
        ])
        
        vertDescriptor.layouts[0].stride = MemoryLayout<CircleVertexData>.stride
        shaderDescriptor.vertexDescriptor = vertDescriptor
        
        let shader = device.makeShader(from: shaderDescriptor)
        let circlePiplineState = device.makePipelineState(for: shader)
        
        let vertexBuffer = device.makeVertexBuffer(
            offset: 0,
            index: 0,
            bytes: nil,
            length: MemoryLayout<CircleVertexData>.stride * Self.maxVerticies
        )
        
        let vertexArray = device.makeVertexArray(vertexBuffers: [vertexBuffer], vertexCount: Self.maxVerticies)
        return Data<CircleVertexData>(
            vertexArray: vertexArray,
            vertexBuffer: vertexBuffer,
            vertices: [],
            indeciesCount: 0,
            indexArray: indexArray,
            piplineState: circlePiplineState
        )
    }
    
    private static func makeQuadData(indexArray: RID) -> Data<QuadVertexData> {
        let device = RenderEngine.shared
        
        var shaderDescriptor = ShaderDescriptor(
            shaderName: "quad",
            vertexFunction: "quad_vertex",
            fragmentFunction: "quad_fragment"
        )
        
        var vertDescriptor = shaderDescriptor.vertexDescriptor
        
        vertDescriptor.attributes.append([
            .attribute(.vector4, name: "position"),
            .attribute(.vector4, name: "color"),
            .attribute(.vector2, name: "textureCoordinate"),
            .attribute(.int, name: "textureIndex"),
        ])
        
        vertDescriptor.layouts[0].stride = MemoryLayout<QuadVertexData>.stride
        shaderDescriptor.vertexDescriptor = vertDescriptor
        
        let shader = device.makeShader(from: shaderDescriptor)
        let quadPiplineState = device.makePipelineState(for: shader)
        
        let vertexBuffer = device.makeVertexBuffer(
            offset: 0,
            index: 0,
            bytes: nil,
            length: MemoryLayout<QuadVertexData>.stride * Self.maxVerticies
        )
        
        let vertexArray = device.makeVertexArray(vertexBuffers: [vertexBuffer], vertexCount: Self.maxVerticies)
        
        return Data<QuadVertexData>(
            vertexArray: vertexArray,
            vertexBuffer: vertexBuffer,
            vertices: [],
            indeciesCount: 0,
            indexArray: indexArray,
            piplineState: quadPiplineState
        )
    }
    
    private static func makeLineData() -> Data<LineVertexData> {
        let device = RenderEngine.shared
        
        var shaderDescriptor = ShaderDescriptor(
            shaderName: "line",
            vertexFunction: "line_vertex",
            fragmentFunction: "line_fragment"
        )
        
        var vertDescriptor = shaderDescriptor.vertexDescriptor
        
        vertDescriptor.attributes.append([
            .attribute(.vector3, name: "position"),
            .attribute(.vector4, name: "color"),
            .attribute(.float, name: "lineWidth"),
        ])
        
        vertDescriptor.layouts[0].stride = MemoryLayout<LineVertexData>.stride
        shaderDescriptor.vertexDescriptor = vertDescriptor
        
        let shader = device.makeShader(from: shaderDescriptor)
        let circlePiplineState = device.makePipelineState(for: shader)
        
        let vertexBuffer = device.makeVertexBuffer(
            offset: 0,
            index: 0,
            bytes: nil,
            length: MemoryLayout<LineVertexData>.stride * Self.maxLineVertices
        )
        
        let vertexArray = device.makeVertexArray(vertexBuffers: [vertexBuffer], vertexCount: Self.maxLineVertices)
        
        var buffer: [Int32] = [Int32].init(repeating: 0, count: Self.maxLineIndices)
        
        for i in 0 ..< Self.maxLineIndices {
            buffer[i] = Int32(i)
        }
        
        let indexBuffer = device.makeIndexBuffer(
            offset: 0,
            index: 0,
            format: .uInt32,
            bytes: &buffer,
            length: Self.maxLineIndices
        )
        
        let indexArray = device.makeIndexArray(indexBuffer: indexBuffer, indexOffset: 0, indexCount: Self.maxLineIndices)
        
        return Data<LineVertexData>(
            vertexArray: vertexArray,
            vertexBuffer: vertexBuffer,
            vertices: [],
            indeciesCount: 0,
            indexArray: indexArray,
            piplineState: circlePiplineState
        )
    }
}
