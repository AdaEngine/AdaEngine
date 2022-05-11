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
        guard self.renderBackend.viewportSize.width > 0 && self.renderBackend.viewportSize.height > 0 else {
            return
        }
        
        try self.renderBackend.beginFrame()
    }
    
    public func endDraw() throws {
        try self.renderBackend.endFrame()
    }
    
    public func initialize(for view: RenderView, size: Size) throws {
        try self.renderBackend.createWindow(for: view, size: size)
    }
    
    public func updateViewSize(newSize: Size) throws {
        guard newSize.width > 0 && newSize.height > 0 else {
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
