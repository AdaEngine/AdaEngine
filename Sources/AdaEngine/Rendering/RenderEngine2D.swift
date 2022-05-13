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
        var view: Transform3D = .identity
    }
    
    var currentDraw: RID!
    var uniformRid: RID
    
    struct Data<V> {
        var vertexArray: RID
        var vertexBuffer: RID
        var vertices: [V] = []
        var indeciesCount: Int = 0
        var piplineState: RID
    }
    
    var circleData: Data<CircleVertexData>
    var quadData: Data<QuadVertexData>
    var quadPosition: [Vector4] = []
    
    var quadIndexBuffer: RID
    var indexArray: RID
    
    static var maxQuads = 100_000
    static var maxVerticies = maxQuads * 4
    static var maxIndecies = maxQuads * 6
    
    private var fillColor: Color = .clear
    
    init() {
        let device = RenderEngine.shared.renderBackend
        
        self.uniformRid = device.makeUniform(Uniform.self, count: 1, index: 1, offset: 0, options: .storageShared)
        
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
    
    /// Create orthogonal transform for this
    public func beginContext(in rect: Rect) {
        self.setOrhoTransform(for: rect)
        self.currentDraw = RenderEngine.shared.renderBackend.beginDrawList()
    }
    
    public func setOrhoTransform(for rect: Rect) {
        let size = rect.size
        
        let transform = Transform3D.orthogonal(
            left: -rect.minX,
            right: size.width,
            top: rect.minY,
            bottom: -size.height,
            zNear: 0,
            zFar: 1
        )
        
        let uni = Uniform(view: transform)
//        self.uniform = uni
        RenderEngine.shared.renderBackend.updateUniform(self.uniformRid, value: uni, count: 1)
    }
    
    public func beginContext(_ camera: Camera) {
        let data = camera.makeCameraData()
        
        let uni = Uniform(view: data.view)
        RenderEngine.shared.renderBackend.updateUniform(self.uniformRid, value: uni, count: 1)
        
        self.currentDraw = RenderEngine.shared.renderBackend.beginDrawList()
    }
    
    public func setFillColor(_ color: Color) {
        self.fillColor = color
    }
    
    public func drawQuad(_ rect: Rect) {
        
        if rect.size.width < 0 || rect.size.height < 0 {
            return
        }
        
        let transform = Transform3D(
            [rect.size.width, 0, 0, 0],
            [0, rect.size.height, 0, 0 ],
            [0, 0, 1.0, 0.0],
            [rect.size.width / 2 + rect.minX, -rect.size.height / 2 + rect.minY, 0, 1]
        )
        
        self.drawQuad(transform: transform)
    }
    
    public func drawQuad(transform: Transform3D) {
        for quad in quadPosition {
            let data = QuadVertexData(
                position: transform * quad,
                color: self.fillColor
            )
            
            self.quadData.vertices.append(data)
        }
        
        self.quadData.indeciesCount += 6
    }
    
    public func setDebugName(_ name: String) {
        RenderEngine.shared.renderBackend.bindDebugName(name: name, forDraw: self.currentDraw)
    }
    
    public func drawCircle(
        transform: Transform3D,
        thickness: Float,
        fade: Float
    ) {
        for quad in quadPosition {
            let data = CircleVertexData(
                worldPosition: transform * quad,
                localPosition: quad * 2,
                thickness: thickness,
                fade: fade,
                color: self.fillColor
            )
            
            self.circleData.vertices.append(data)
        }
        
        self.circleData.indeciesCount += 6
    }
    
    public func commitContext() {
        
        let device = RenderEngine.shared.renderBackend
        
        device.bindUniformSet(self.currentDraw, uniformSet: self.uniformRid)
        
        if self.quadData.indeciesCount > 0 {
            device.setVertexBufferData(
                self.quadData.vertexBuffer,
                bytes: self.quadData.vertices,
                length: self.quadData.vertices.count * MemoryLayout<QuadVertexData>.stride
            )
           
            device.bindVertexArray(self.currentDraw, vertexArray: self.quadData.vertexArray)
            device.bindRenderState(self.currentDraw, renderPassId: self.quadData.piplineState)
            device.bindIndexArray(self.currentDraw, indexArray: self.indexArray)
            
            device.draw(self.currentDraw, indexCount: self.quadData.indeciesCount, instancesCount: 1)
        }
        
        if self.circleData.indeciesCount > 0 {
            
            device.setVertexBufferData(
                self.circleData.vertexBuffer,
                bytes: self.circleData.vertices,
                length: self.circleData.vertices.count * MemoryLayout<CircleVertexData>.stride
            )
           
            device.bindVertexArray(self.currentDraw, vertexArray: self.circleData.vertexArray)
            device.bindRenderState(self.currentDraw, renderPassId: self.circleData.piplineState)
            device.bindIndexArray(self.currentDraw, indexArray: self.indexArray)
            
            device.draw(self.currentDraw, indexCount: self.circleData.indeciesCount, instancesCount: 1)
        }
        
        device.drawEnd(self.currentDraw)
        self.currentDraw = nil
        
        self.clearContext()
    }
     
    public func clearContext() {
        self.uniform.view = .identity
        
        self.circleData.vertices.removeAll(keepingCapacity: true)
        self.circleData.indeciesCount = 0
        
        self.quadData.vertices.removeAll(keepingCapacity: true)
        self.quadData.indeciesCount = 0
        
        self.fillColor = .clear
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
            vertices: [],
            indeciesCount: 0,
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
            vertices: [],
            indeciesCount: 0,
            piplineState: quadPiplineState
        )
    }
    
}
