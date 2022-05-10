//
//  RenderEngine2D.swift
//  
//
//  Created by v.prusakov on 5/10/22.
//

public class RenderEngine2D {
    
    public static let shared = RenderEngine2D()
    
    private var uniform: Uniform = Uniform()
    
    struct Uniform {
        var view: Transform3D = .identity
    }
    
    var currentDraw: RID!
    var uniformRid: RID
    
    struct QuadData {
        var indexBuffer: RID
        var vertexBuffer: RID
        var quadVertexData: [QuadVertexData] = []
        var quadIndexCount: Int = 0
        var piplineState: RID
    }
    
    struct CircleData {
        var indexBuffer: RID
        var vertexBuffer: RID
        var circleVertex: [CircleVertexData] = []
        var circleIndexCount: Int = 0
        var piplineState: RID
    }
    
    var circleData: CircleData
    var quadData: QuadData
    var quadPosition: [Vector4] = []
    
    static var maxQuads = 20000
    static var maxVerticies = maxQuads * 4
    static var maxIndecies = maxQuads * 6
    
    init() {
        let device = RenderEngine.shared.renderBackend
        
        self.uniformRid = device.makeUniform(Uniform.self, count: 1, index: 1, offset: 0, options: .storageShared)
        
        self.quadPosition = [
            [-0.5,  0.5, 0.0, 1.0],
            [0.5,   0.5, 0.0, 1.0],
            [0.5,   -0.5,  0.0, 1.0],
            [-0.5,  -0.5,  0.0, 1.0]
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
        
        let quadIndexBuffer = device.makeIndexBuffer(
            offset: 0,
            index: 0,
            bytes: &quadIndices,
            length: Self.maxIndecies
        )
        
        self.circleData = Self.makeCircleData(quadIndexBuffer: quadIndexBuffer)
        self.quadData = Self.makeQuadData(quadIndexBuffer: quadIndexBuffer)
    }
    
    public func beginContext(_ camera: Camera) {
        let data = camera.makeCameraData()
        
        let uni = Uniform(view: data.view)
        RenderEngine.shared.renderBackend.updateUniform(self.uniformRid, value: uni, count: 1)
        
        self.currentDraw = RenderEngine.shared.renderBackend.beginDrawList()
    }
    
    public func drawQuad(transform: Transform3D, color: Color) {
        for quad in quadPosition {
            let data = QuadVertexData(
                position: transform * quad,
                color: color
            )
            
            self.quadData.quadVertexData.append(data)
        }
        
        self.quadData.quadIndexCount += 6
    }
    
    public func setDebugName(_ name: String) {
        RenderEngine.shared.renderBackend.bindDebugName(name: name, forDraw: self.currentDraw)
    }
    
    public func drawCircle(
        transform: Transform3D,
        color: Color,
        thickness: Float,
        fade: Float
    ) {
        for quad in quadPosition {
            let data = CircleVertexData(
                worldPosition: transform * quad,
                localPosition: quad * 2,
                thickness: thickness,
                fade: fade,
                color: color
            )
            
            self.circleData.circleVertex.append(data)
        }
        
        self.circleData.circleIndexCount += 6
    }
    
    public func commitContext() {
        
        let device = RenderEngine.shared.renderBackend
        
        device.bindUniformSet(self.currentDraw, uniformSet: self.uniformRid)
        
        if self.quadData.quadIndexCount > 0 {
            device.setVertexBufferData(
                self.quadData.vertexBuffer,
                bytes: self.quadData.quadVertexData,
                length: self.quadData.quadVertexData.count * MemoryLayout<QuadVertexData>.stride
            )
           
            device.bindVertexBuffer(self.currentDraw, vertexBuffer: self.quadData.vertexBuffer)
            device.bindRenderState(self.currentDraw, renderPassId: self.quadData.piplineState)
            device.bindIndexBuffer(self.currentDraw, indexBuffer: self.quadData.indexBuffer)
            
            device.draw(self.currentDraw, indexCount: self.quadData.quadIndexCount, instancesCount: 1)
        }
        
        if self.circleData.circleIndexCount > 0 {
            
            device.setVertexBufferData(
                self.circleData.vertexBuffer,
                bytes: self.circleData.circleVertex,
                length: self.circleData.circleVertex.count * MemoryLayout<CircleVertexData>.stride
            )
           
            device.bindVertexBuffer(self.currentDraw, vertexBuffer: self.circleData.vertexBuffer)
            device.bindRenderState(self.currentDraw, renderPassId: self.circleData.piplineState)
            device.bindIndexBuffer(self.currentDraw, indexBuffer: self.circleData.indexBuffer)
            
            device.draw(self.currentDraw, indexCount: self.circleData.circleIndexCount, instancesCount: 1)
        }
        
        device.drawEnd(self.currentDraw)
        self.currentDraw = nil
        
        self.clearContext()
    }
     
    public func clearContext() {
        uniform.view = .identity
        
        
        self.circleData.circleVertex.removeAll(keepingCapacity: true)
        self.circleData.circleIndexCount = 0
        
        self.quadData.quadVertexData.removeAll(keepingCapacity: true)
        self.quadData.quadIndexCount = 0
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
    
    private static func makeCircleData(quadIndexBuffer: RID) -> CircleData {
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
        
        let circleVertexBuffer = device.makeVertexBuffer(
            offset: 0,
            index: 0,
            bytes: nil,
            length: MemoryLayout<CircleVertexData>.stride * Self.maxVerticies
        )
        
        return CircleData(
            indexBuffer: quadIndexBuffer,
            vertexBuffer: circleVertexBuffer,
            circleVertex: [],
            circleIndexCount: 0,
            piplineState: circlePiplineState
        )
    }
    
    private static func makeQuadData(quadIndexBuffer: RID) -> QuadData {
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
        
        return QuadData(
            indexBuffer: quadIndexBuffer,
            vertexBuffer: vertexBuffer,
            quadVertexData: [],
            quadIndexCount: 0,
            piplineState: quadPiplineState
        )
    }
    
}
