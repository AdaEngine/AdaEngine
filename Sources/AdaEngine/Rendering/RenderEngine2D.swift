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
        for i in stride(from: 0, to: Self.maxIndecies, by: 6) {
            quadIndices[i + 0] = offset + 0
            quadIndices[i + 1] = offset + 1
            quadIndices[i + 2] = offset + 2

            quadIndices[i + 3] = offset + 2
            quadIndices[i + 4] = offset + 3
            quadIndices[i + 5] = offset + 0

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
    
    public func beginContext(for viewTransform: Transform3D) {
        let uni = Uniform(viewProjection: viewTransform)
        RenderEngine.shared.renderBackend.updateUniform(self.uniformRid, value: uni, count: 1)
        
        self.currentDraw = RenderEngine.shared.renderBackend.beginDraw()
        self.startBatch()
    }
    
    public func setZIndex(_ index: Int) {
        self.currentZIndex = index
    }
    
    public func beginContext(_ camera: Camera) {
        let data = camera.makeCameraData()
        let viewProjection = data.projection * data.view
        let uni = Uniform(viewProjection: viewProjection * camera.transform.matrix.inverse)
        RenderEngine.shared.renderBackend.updateUniform(self.uniformRid, value: uni, count: 1)
        
        self.currentDraw = RenderEngine.shared.renderBackend.beginDraw()
        self.startBatch()
    }
    
    public func drawQuad(transform: Transform3D, color: Color) {
        
        if self.quadData.indeciesCount.count >= Self.maxIndecies {
            self.nextBatch()
        }
        
        for quad in quadPosition {
            let data = QuadVertexData(
                position: transform * quad,
                color: color
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
                worldPosition: transform * quad,
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
            
            let indecies = self.quadData.vertices.keys.sorted()
            
            for index in indecies {
                let verticies = self.quadData.vertices[index]!
                
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
    }
    
    private static func makeCircleData() -> Data<CircleVertexData> {
        let device = RenderEngine.shared.renderBackend
        
        let shader = device.makeShader("default", vertexFuncName: "circle_vertex", fragmentFuncName: "circle_fragment")
        
        var circleVertexDescriptor = VertexDesciptorAttributesArray()
        circleVertexDescriptor[0].format = .vector4
        circleVertexDescriptor[0].bufferIndex = 0
        circleVertexDescriptor[0].offset = MemoryLayout.offset(of: \CircleVertexData.worldPosition)!
        
        circleVertexDescriptor[1].format = .vector4
        circleVertexDescriptor[1].bufferIndex = 0
        circleVertexDescriptor[1].offset = MemoryLayout.offset(of: \CircleVertexData.localPosition)!

        circleVertexDescriptor[2].format = .float
        circleVertexDescriptor[2].bufferIndex = 0
        circleVertexDescriptor[2].offset = MemoryLayout.offset(of: \CircleVertexData.thickness)!

        circleVertexDescriptor[3].format = .float
        circleVertexDescriptor[3].bufferIndex = 0
        circleVertexDescriptor[3].offset = MemoryLayout.offset(of: \CircleVertexData.fade)!

        circleVertexDescriptor[4].format = .vector4
        circleVertexDescriptor[4].bufferIndex = 0
        circleVertexDescriptor[4].offset = MemoryLayout.offset(of: \CircleVertexData.color)!
        
        var layouts = VertexDesciptorLayoutsArray()
        layouts[0].stride = MemoryLayout<CircleVertexData>.stride
        
        device.bindAttributes(attributes: circleVertexDescriptor, forShader: shader)
        device.bindLayouts(layouts: layouts, forShader: shader)
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
        
        let shader = device.makeShader("default", vertexFuncName: "quad_vertex", fragmentFuncName: "quad_fragment")
        
        var quadVertexAttributes = VertexDesciptorAttributesArray()
        quadVertexAttributes[0].format = .vector4
        quadVertexAttributes[0].bufferIndex = 0
        quadVertexAttributes[0].offset = MemoryLayout.offset(of: \QuadVertexData.position)!
        
        quadVertexAttributes[1].format = .vector4
        quadVertexAttributes[1].bufferIndex = 0
        quadVertexAttributes[1].offset = MemoryLayout.offset(of: \QuadVertexData.color)!
        
        var layouts = VertexDesciptorLayoutsArray()
        layouts[0].stride = MemoryLayout<QuadVertexData>.stride
        
        device.bindAttributes(attributes: quadVertexAttributes, forShader: shader)
        device.bindLayouts(layouts: layouts, forShader: shader)
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
