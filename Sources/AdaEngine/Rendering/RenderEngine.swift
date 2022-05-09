//
//  RenderEngine.swift
//  
//
//  Created by v.prusakov on 10/25/21.
//

import OrderedCollections
import Foundation

public class RenderEngine {
    
    public static var shared: RenderEngine!
    
    public enum BackendType: UInt {
        case metal
        case vulkan
    }
    
    public let backendType: BackendType
    
    let renderBackend: RenderBackend
    
    private init(backendType: BackendType, renderBackend: RenderBackend) {
        self.backendType = backendType
        self.renderBackend = renderBackend
    }
    
    static func createRenderEngine(backendType: BackendType, appName: String) throws -> RenderEngine {
        
        let renderBackend: RenderBackend
        
        switch backendType {
        case .metal:
            renderBackend = MetalRenderBackend(appName: appName)
        case .vulkan:
            fatalError()
        }
        
        let renderEngine = RenderEngine(backendType: backendType, renderBackend: renderBackend)
        Self.shared = renderEngine
        
        return renderEngine
    }
    
    // MARK: Methods
    
    public func draw() throws {
        guard self.renderBackend.viewportSize.x > 0 && self.renderBackend.viewportSize.y > 0 else {
            return
        }
        
        //        let cameraData = CameraManager.shared.makeCurrentCameraData()
        //        self.renderBackend.renderDrawableList(self.drawableList, camera: cameraData)
        
        try self.renderBackend.beginFrame()
        
        try self.renderBackend.endFrame()
    }
    
    public func initialize(for view: RenderView, size: Vector2i) throws {
        try self.renderBackend.createWindow(for: view, size: size)
    }
    
    public func updateViewSize(newSize: Vector2i) throws {
        guard newSize.x > 0 && newSize.y > 0 else {
            return
        }
        
        try self.renderBackend.resizeWindow(newSize: newSize)
    }
    
    func makeDrawable() -> Drawable {
        let drawable = Drawable()
        drawable.renderEngine = self
        return drawable
    }
    
    func setDrawableToQueue(_ drawable: Drawable, layer: Int) {
        
    }
    
    func removeDrawableFromQueue(_ drawable: Drawable) {
        
    }
    
    func makePipelineDescriptor(for drawable: Drawable) {
        // TODO: Should create pipeline descriptor cache
        guard let material = drawable.materials?.first else { return }
        
        switch drawable.source {
        case .mesh(let mesh):
            drawable.pipelineState = self.renderBackend.makePipelineDescriptor(for: material, vertexDescriptor: mesh.vertexDescriptor)
        default:
            drawable.pipelineState = self.renderBackend.makePipelineDescriptor(for: material, vertexDescriptor: nil)
        }
        
    }
    
    // MARK: - Buffers
    
    func makeBuffer(length: Int, options: ResourceOptions) -> RID {
        return self.renderBackend.makeBuffer(length: length, options: options)
    }
    
    func makeBuffer(bytes: UnsafeRawPointer, length: Int, options: ResourceOptions) -> RID {
        return self.renderBackend.makeBuffer(bytes: bytes, length: length, options: options)
    }
    
    func getBuffer(for rid: RID) -> RenderBuffer {
        return self.renderBackend.getBuffer(for: rid)
    }
}

public class Drawable: Identifiable {
    
    enum Source {
        case mesh(Mesh)
        case light
        
        case empty
    }
    
    internal weak var renderEngine: RenderEngine?
    
    public let id: UUID = UUID()
    
    var source: Source = .empty
    var transform: Transform3D = .identity
    
    var materials: [Material]? {
        didSet {
            self.renderEngine?.makePipelineDescriptor(for: self)
        }
    }
    
    var position: Vector3 = .zero
    
    var layer: Int = 0
    
    var isVisible = true
    
    internal var pipelineState: RID?
}

extension Drawable: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(position)
    }
    
    public static func == (lhs: Drawable, rhs: Drawable) -> Bool {
        lhs.id == rhs.id && lhs.position == rhs.position && lhs.transform == rhs.transform
    }
}

final class DrawableList {
    var drawables: OrderedDictionary<Int, Set<Drawable>> = [:]
}

struct CircleVertexData {
    var worldPosition: Vector3
    var localPosition: Vector3
    let thickness: Float
    let fade: Float
    let color: Color
}

public class RenderEngine2D {
    
    static let shared = RenderEngine2D()
    
    private var uniform: Uniform = Uniform()
    
    struct Uniform {
        var view: Transform3D = .identity
    }
    
    var currentDraw: RID!
    var uniformRid: RID
    var indexBuffer: RID!
    var vertexBuffer: RID!
    
    var quadPosition: [Vector3] = []
    var circleVertex: [CircleVertexData] = []
    var circleIndexCount: Int = 0
    
    var circlePiplineState: RID
    
    init() {
        let device = RenderEngine.shared.renderBackend
        
        self.uniformRid = device.makeUniform(Uniform.self, count: 1, index: 1, offset: 0, options: .storageShared)
        
        let shader = device.makeShader("circle", vertexFuncName: "vertex_main", fragmentFuncName: "fragment_main")
        
        var circleVertexDescriptor = VertexDesciptorAttributesArray()
        circleVertexDescriptor[0].format = .vector3
        circleVertexDescriptor[0].bufferIndex = 0
        circleVertexDescriptor[0].offset = MemoryLayout.offset(of: \CircleVertexData.worldPosition)!
        
        circleVertexDescriptor[1].format = .vector3
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
        self.circlePiplineState = device.makePipelineState(for: shader)
        
        self.quadPosition = [
            [-0.5,  -0.5, 0.0],
            [0.5,   -0.5, 0.0],
            [0.5,   0.5,  0.0],
            [-0.5,  0.5,  0.0]
        ]
    }
    
    public func beginContext(_ camera: Camera) {
        let data = camera.makeCameraData()
        
        var uni = Uniform(view: data.view)
        RenderEngine.shared.renderBackend.updateUniform(self.uniformRid, value: uni, count: 1)
        
        self.currentDraw = RenderEngine.shared.renderBackend.beginDrawList()
    }
    
    public func drawQuad() {
        
    }
    
    public func setDebugName(_ name: String) {
        RenderEngine.shared.renderBackend.bindDebugName(name: name, forDraw: self.currentDraw)
    }
    
    public func drawCircle(
        transform: Transform3D,
        color: Color,
        radius: Float,
        thickness: Float,
        fade: Float
    ) {
        for quad in quadPosition {
            let data = CircleVertexData(
                worldPosition: transform.origin * quad,
                localPosition: quad * 2,
                thickness: thickness,
                fade: fade,
                color: color
            )
            
            self.circleVertex.append(data)
        }
        
        self.circleIndexCount += 6
    }
    
    public func commitContext() {
        
        let device = RenderEngine.shared.renderBackend
        
        device.bindUniformSet(self.currentDraw, uniformSet: self.uniformRid)
        
        if self.circleIndexCount > 0 {
            
            let vertexBuffer = device.makeVertexBuffer(
                offset: 0,
                index: 0,
                bytes: &self.circleVertex,
                length: MemoryLayout<CircleVertexData>.size * self.circleVertex.count
            )
            
            let indexBuffer = device.makeIndexBuffer(
                offset: 0,
                index: 0,
                bytes: &quadPosition,
                length: MemoryLayout<Vector3>.size * circleIndexCount
            )
            
            device.bindVertexBuffer(self.currentDraw, vertexBuffer: vertexBuffer)
            device.bindRenderState(self.currentDraw, renderPassId: self.circlePiplineState)
            device.bindIndexBuffer(self.currentDraw, indexBuffer: indexBuffer)
            
            device.draw(self.currentDraw, indexCount: self.circleIndexCount, instancesCount: 1)
        }
        
        
        self.clear()
    }
    
    // MARK: - Private
    
    private func clear() {
        uniform.view = .identity
        self.circleVertex.removeAll(keepingCapacity: true)
    }
}
