//
//  RenderEngine2D.swift
//  
//
//  Created by v.prusakov on 5/10/22.
//

import Math

// TODO: (Vlad) Render engine shouldn't use current draw, because it can be raise a conflict in multiple windows or nested scenes!
public class RenderEngine2D {
    
//    public static let shared = RenderEngine2D()
    
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
    
    var textureSlots: [Texture2D?]
    var textureSlotIndex = 1
    let whiteTexture: Texture2D
    
    var quadIndexBuffer: RID
    var indexArray: RID
    
    static var maxQuads = 20_000
    static var maxVerticies = maxQuads * 4
    static var maxIndecies = maxQuads * 6
    
    private var fillColor: Color = .clear
    
    var currentZIndex: Int = 0
    var triangleFillMode: TriangleFillMode = .fill
    
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
        
        self.quadIndexBuffer = device.makeIndexBuffer(
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
        
        self.indexArray = device.makeIndexArray(indexBuffer: self.quadIndexBuffer, indexOffset: 0, indexCount: Self.maxIndecies)
        
        self.circleData = Self.makeCircleData()
        self.quadData = Self.makeQuadData()
    }
    
    public func beginContext(for window: Window.ID, viewTransform: Transform3D) {
        let uni = Uniform(viewProjection: viewTransform)
        RenderEngine.shared.updateUniform(self.uniformRid, value: uni, count: 1)
        
        self.currentDraw = RenderEngine.shared.beginDraw(for: window)
        self.startBatch()
    }
    
    public func setZIndex(_ index: Int) {
        self.currentZIndex = index
    }
    
    public func beginContext(for window: Window.ID, camera: Camera) {
        let data = camera.makeCameraData()
        let uni = Uniform(viewProjection: camera.transform.matrix * data.viewProjection)
        RenderEngine.shared.updateUniform(self.uniformRid, value: uni, count: 1)
        
        self.currentDraw = RenderEngine.shared.beginDraw(for: window)
        self.startBatch()
    }
    
    public func drawQuad(position: Vector3, size: Vector2, texture: Texture2D? = nil, color: Color) {
        let transform = Transform3D(translation: position) * Transform3D(scale: Vector3(size, 1))
        self.drawQuad(transform: transform, texture: texture, color: color)
    }
    
    public func drawQuad(transform: Transform3D, texture: Texture2D? = nil, color: Color) {
        
        if self.quadData.indeciesCount.count >= Self.maxIndecies {
            self.nextBatch()
        }
        
        // Flush all data if textures count more than 32
        if self.textureSlotIndex >= 31 {
            self.nextBatch()
            self.textureSlots.removeAll(keepingCapacity: true)
            self.textureSlots[0] = self.whiteTexture
            self.textureSlotIndex = 1
        }
        
        // Select a texture index for draw
        
        let textureIndex: Int
        
        if let texture = texture {
            if let index = self.textureSlots.firstIndex(where: { $0 == texture }) {
                textureIndex = index
            } else {
                self.textureSlots[self.textureSlotIndex] = texture
                textureIndex = self.textureSlotIndex
                self.textureSlotIndex += 1
            }
        } else {
            // for white texture
            textureIndex = 0
        }
        
        let texture = self.textureSlots[textureIndex]
        
        for index in 0 ..< quadPosition.count {
            let data = QuadVertexData(
                position: quadPosition[index] * transform,
                color: color,
                textureCoordinate: texture!.textureCoordinates[index],
                textureIndex: textureIndex
            )
            
            self.quadData.vertices[self.currentZIndex, default: []].append(data)
        }
        
        self.quadData.indeciesCount[self.currentZIndex, default: 0] += 6
    }
    
    public func setDebugName(_ name: String) {
        RenderEngine.shared.bindDebugName(name: name, forDraw: self.currentDraw)
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
        
        RenderEngine.shared.drawEnd(self.currentDraw)
        self.currentDraw = nil
        
        self.clearContext()
    }
     
    public func clearContext() {
        self.uniform.viewProjection = .identity
        self.triangleFillMode = .fill
    }
    
    public func setTriangleFillMode(_ mode: TriangleFillMode) {
        self.triangleFillMode = mode
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
        guard let currentDraw = self.currentDraw else {
            return
        }
        
        let device = RenderEngine.shared
        
        device.bindUniformSet(currentDraw, uniformSet: self.uniformRid, at: BufferIndex.baseUniform)
        device.bindTriangleFillMode(currentDraw, mode: self.triangleFillMode)
        
        if !self.quadData.indeciesCount.isEmpty {
            
            let indicies = self.quadData.vertices.keys.sorted()
            
            for index in indicies {
                let verticies = self.quadData.vertices[index]!
                
                let textures = self.textureSlots[0..<self.textureSlotIndex].compactMap { $0 }
                
                for (index, texture) in textures.enumerated() {
                    device.bindTexture(currentDraw, texture: texture.rid, at: index)
                }
                
                device.setVertexBufferData(
                    self.quadData.vertexBuffer,
                    bytes: verticies,
                    length: verticies.count * MemoryLayout<QuadVertexData>.stride
                )
               
                device.bindVertexArray(currentDraw, vertexArray: self.quadData.vertexArray)
                device.bindRenderState(currentDraw, renderPassId: self.quadData.piplineState)
                device.bindIndexArray(currentDraw, indexArray: self.indexArray)
                
                device.draw(currentDraw, indexCount: self.quadData.indeciesCount[index]!, instancesCount: 1)
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
               
                device.bindVertexArray(currentDraw, vertexArray: self.circleData.vertexArray)
                device.bindRenderState(currentDraw, renderPassId: self.circleData.piplineState)
                device.bindIndexArray(currentDraw, indexArray: self.indexArray)
                
                device.draw(currentDraw, indexCount: self.circleData.indeciesCount[index]!, instancesCount: 1)
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
        let textureIndex: Int
    }
    
    private static func makeCircleData() -> Data<CircleVertexData> {
        let device = RenderEngine.shared

        let shaderName: String
        #if SWIFT_PACKAGE
        shaderName = "circle.metal"
        #else
        shaderName = "default.metallib"
        #endif
        
        var shaderDescriptor = ShaderDescriptor(
            shaderName: shaderName,
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
        let device = RenderEngine.shared

        // FIXME: We should compile metal
        let shaderName: String
        #if SWIFT_PACKAGE
        shaderName = "quad.metal"
        #else
        shaderName = "default.metallib"
        #endif

        var shaderDescriptor = ShaderDescriptor(
            shaderName: shaderName,
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
        
        vertDescriptor.attributes[3].format = .int
        vertDescriptor.attributes[3].bufferIndex = 0
        vertDescriptor.attributes[3].offset = MemoryLayout.offset(of: \QuadVertexData.textureIndex)!
        
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
