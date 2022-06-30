//
//  RenderEngine2D.swift
//  
//
//  Created by v.prusakov on 5/10/22.
//

import Math

public class RenderEngine2D {
    
    public static let shared = RenderEngine2D()
    
    private var uniform: Uniform = Uniform()
    
    struct Uniform {
        var viewProjection: Transform3D = .identity
    }
    
    var currentDraw: RID!
    var uniformRid: RID
    
    struct Data<V> {
        var vertexArray: RID
        var vertexBuffer: RID
        var vertices: [Int: [V]] = [:]
        var indeciesCount: [Int: Int] = [:]
        var piplineState: RID
        var textureSlots: [Texture2D] = []
    }
    
    var circleData: Data<CircleVertexData>
    var quadData: Data<QuadVertexData>
    var quadPosition: [Vector4] = []
    
    var quadIndexBuffer: RID
    var indexArray: RID
    
    static var maxQuads = 20_000
    static var maxVerticies = maxQuads * 4
    static var maxIndecies = maxQuads * 6
    
    private var fillColor: Color = .clear
    
    var currentZIndex: Int = 0
    
    init() {
        let device = RenderEngine.shared.renderBackend
        
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
        
        self.quadIndexBuffer = device.makeIndexBuffer(
            offset: 0,
            index: 0,
            format: .uInt32,
            bytes: &quadIndices,
            length: Self.maxIndecies
        )
        
        self.indexArray = device.makeIndexArray(indexBuffer: self.quadIndexBuffer, indexOffset: 0, indexCount: Self.maxIndecies)
        
        self.circleData = Self.makeCircleData()
        self.quadData = Self.makeQuadData()
    }
    
    public func beginContext(for window: Window.ID, viewTransform: Transform3D) {
        let uni = Uniform(viewProjection: viewTransform)
        RenderEngine.shared.renderBackend.updateUniform(self.uniformRid, value: uni, count: 1)
        
        self.currentDraw = RenderEngine.shared.renderBackend.beginDraw(for: window)
        self.startBatch()
    }
    
    public func setZIndex(_ index: Int) {
        self.currentZIndex = index
    }
    
    public func beginContext(for window: Window.ID, camera: Camera) {
        let data = camera.makeCameraData()
        let uni = Uniform(viewProjection: camera.transform.matrix * data.viewProjection)
        RenderEngine.shared.renderBackend.updateUniform(self.uniformRid, value: uni, count: 1)
        
        self.currentDraw = RenderEngine.shared.renderBackend.beginDraw(for: window)
        self.startBatch()
    }
    
    public func drawQuad(transform: Transform3D, texture: Texture2D? = nil, color: Color) {
        
        if self.quadData.indeciesCount.count >= Self.maxIndecies {
            self.nextBatch()
        }
        
        // TODO: Not efficient
        if let texture = texture, !self.quadData.textureSlots.contains(where: { $0.rid == texture.rid }) {
            self.quadData.textureSlots.append(texture)
        }
        
        for index in 0..<quadPosition.count {
            let data = QuadVertexData(
                position: quadPosition[index] * transform,
                color: color,
                textureCoordinate: texture?.textureCoordinates[index] ?? .zero
            )
            
            self.quadData.vertices[self.currentZIndex, default: []].append(data)
        }
        
        self.quadData.indeciesCount[self.currentZIndex, default: 0] += 6
    }
    
    public func setDebugName(_ name: String) {
        RenderEngine.shared.renderBackend.bindDebugName(name: name, forDraw: self.currentDraw)
    }
    
    public func drawCircle(
        transform: Transform3D,
        thickness: Float,
        fade: Float,
        color: Color
    ) {
        
        if self.circleData.indeciesCount.count >= Self.maxIndecies {
            self.nextBatch()
        }
        
        for quad in quadPosition {
            let data = CircleVertexData(
                worldPosition: quad * transform,
                localPosition: quad * 2,
                thickness: thickness,
                fade: fade,
                color: color
            )
            
            self.circleData.vertices[self.currentZIndex, default: []].append(data)
        }
        
        self.circleData.indeciesCount[self.currentZIndex, default: 0] += 6
    }
    
    public func commitContext() {
        self.flush()
        
        RenderEngine.shared.renderBackend.drawEnd(self.currentDraw)
        self.currentDraw = nil
        
        self.clearContext()
    }
     
    public func clearContext() {
        self.uniform.viewProjection = .identity
    }
    
    func nextBatch() {
        self.flush()
        self.startBatch()
    }
    
    func startBatch() {
        self.currentZIndex = 0
        
        self.circleData.vertices.removeAll(keepingCapacity: true)
        self.circleData.indeciesCount.removeAll(keepingCapacity: true)
        
        self.quadData.vertices.removeAll(keepingCapacity: true)
        self.quadData.indeciesCount.removeAll(keepingCapacity: true)
    }
    
    public func flush() {
        let device = RenderEngine.shared.renderBackend
        
        device.bindUniformSet(self.currentDraw, uniformSet: self.uniformRid, at: BufferIndex.baseUniform)
        
        if !self.quadData.indeciesCount.isEmpty {
            
            let indicies = self.quadData.vertices.keys.sorted()
            
            for index in indicies {
                let verticies = self.quadData.vertices[index]!
                
                for texture in self.quadData.textureSlots {
                    device.bindTexture(self.currentDraw, texture: texture.rid, at: 0)
                }
                
                device.setVertexBufferData(
                    self.quadData.vertexBuffer,
                    bytes: verticies,
                    length: verticies.count * MemoryLayout<QuadVertexData>.stride
                )
               
                device.bindVertexArray(self.currentDraw, vertexArray: self.quadData.vertexArray)
                device.bindRenderState(self.currentDraw, renderPassId: self.quadData.piplineState)
                device.bindIndexArray(self.currentDraw, indexArray: self.indexArray)
                
                device.draw(self.currentDraw, indexCount: self.quadData.indeciesCount[index]!, instancesCount: 1)
            }
        }
        
        if !self.circleData.indeciesCount.isEmpty {
            
            let indecies = self.circleData.vertices.keys.sorted()
            
            for index in indecies {
                let verticies = self.circleData.vertices[index]!
                
                device.setVertexBufferData(
                    self.circleData.vertexBuffer,
                    bytes: verticies,
                    length: verticies.count * MemoryLayout<CircleVertexData>.stride
                )
               
                device.bindVertexArray(self.currentDraw, vertexArray: self.circleData.vertexArray)
                device.bindRenderState(self.currentDraw, renderPassId: self.circleData.piplineState)
                device.bindIndexArray(self.currentDraw, indexArray: self.indexArray)
                
                device.draw(self.currentDraw, indexCount: self.circleData.indeciesCount[index]!, instancesCount: 1)
            }
        }
    }
}

extension RenderEngine2D {
    
    struct CircleVertexData {
        var worldPosition: Vector4
        var localPosition: Vector4
        let thickness: Float
        let fade: Float
        let color: Color
    }
    
    struct QuadVertexData {
        var position: Vector4
        var color: Color
        var textureCoordinate: Vector2
    }
    
    private static func makeCircleData() -> Data<CircleVertexData> {
        let device = RenderEngine.shared.renderBackend
        
        var shaderDescriptor = ShaderDescriptor(
            shaderName: "default",
            vertexFunction: "circle_vertex",
            fragmentFunction: "circle_fragment"
        )
        
        var vertDescriptor = shaderDescriptor.vertexDescriptor
        
        vertDescriptor.attributes[0].format = .vector4
        vertDescriptor.attributes[0].bufferIndex = 0
        vertDescriptor.attributes[0].offset = MemoryLayout.offset(of: \CircleVertexData.worldPosition)!
        
        vertDescriptor.attributes[1].format = .vector4
        vertDescriptor.attributes[1].bufferIndex = 0
        vertDescriptor.attributes[1].offset = MemoryLayout.offset(of: \CircleVertexData.localPosition)!

        vertDescriptor.attributes[2].format = .float
        vertDescriptor.attributes[2].bufferIndex = 0
        vertDescriptor.attributes[2].offset = MemoryLayout.offset(of: \CircleVertexData.thickness)!

        vertDescriptor.attributes[3].format = .float
        vertDescriptor.attributes[3].bufferIndex = 0
        vertDescriptor.attributes[3].offset = MemoryLayout.offset(of: \CircleVertexData.fade)!

        vertDescriptor.attributes[4].format = .vector4
        vertDescriptor.attributes[4].bufferIndex = 0
        vertDescriptor.attributes[4].offset = MemoryLayout.offset(of: \CircleVertexData.color)!
        
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
            vertices: [:],
            indeciesCount: [:],
            piplineState: circlePiplineState
        )
    }
    
    private static func makeQuadData() -> Data<QuadVertexData> {
        let device = RenderEngine.shared.renderBackend
        
        var shaderDescriptor = ShaderDescriptor(
            shaderName: "default",
            vertexFunction: "quad_vertex",
            fragmentFunction: "quad_fragment"
        )
        
        var vertDescriptor = shaderDescriptor.vertexDescriptor

        vertDescriptor.attributes[0].format = .vector4
        vertDescriptor.attributes[0].bufferIndex = 0
        vertDescriptor.attributes[0].offset = MemoryLayout.offset(of: \QuadVertexData.position)!
        
        vertDescriptor.attributes[1].format = .vector4
        vertDescriptor.attributes[1].bufferIndex = 0
        vertDescriptor.attributes[1].offset = MemoryLayout.offset(of: \QuadVertexData.color)!
        
        vertDescriptor.attributes[2].format = .vector2
        vertDescriptor.attributes[2].bufferIndex = 0
        vertDescriptor.attributes[2].offset = MemoryLayout.offset(of: \QuadVertexData.textureCoordinate)!
        
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
            vertices: [:],
            indeciesCount: [:],
            piplineState: quadPiplineState
        )
    }
}
