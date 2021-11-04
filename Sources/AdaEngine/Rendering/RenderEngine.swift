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
    
    var drawableList: DrawableList = DrawableList()
    
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
        let cameraData = CameraManager.shared.makeCurrentCameraData(viewportSize: self.renderBackend.viewportSize)
        self.renderBackend.renderDrawableList(self.drawableList, camera: cameraData)
        
        try self.renderBackend.beginFrame()
        
        try self.renderBackend.endFrame()
    }
    
    public func initialize(for view: RenderView, size: Vector2i) throws {
        try self.renderBackend.createWindow(for: view, size: size)
    }
    
    public func updateViewSize(newSize: Vector2i) throws {
        try self.renderBackend.resizeWindow(newSize: newSize)
    }
    
    func makeDrawable() -> Drawable {
        return Drawable(id: UUID().uuidString)
    }
    
    func setDrawableToQueue(_ drawable: Drawable) {
        self.drawableList.drawables.updateOrAppend(drawable)
    }
    
    func removeDrawableFromQueue(_ drawable: Drawable) {
        self.drawableList.drawables.remove(drawable)
    }
    
    // MARK: - Buffers
    
    func makeBuffer(length: Int, options: UInt) -> RenderBuffer {
        return self.renderBackend.makeBuffer(length: length, options: options)
    }
    
    func makeBuffer(bytes: UnsafeRawPointer, length: Int, options: UInt) -> RenderBuffer {
        return self.renderBackend.makeBuffer(bytes: bytes, length: length, options: options)
    }
    
}

public struct Drawable: Identifiable {
    
    enum Source {
        case mesh(Mesh)
        case light
        
        case empty
    }
    
    public let id: String
    
    var source: Source = .empty
    var transform: Transform3D = .identity
    
    var position: Vector3 = .zero
    
    var isVisible = true
    
    internal init(id: String) {
        self.id = id
    }
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
    var drawables: OrderedSet<Drawable> = []
}

public class SceneRenderer {
    
    struct Camera {
        var projection: Transform3D
        var view: Transform3D
    }
    
    private var camera: Camera
    
    unowned let renderBackend: RenderBackend
    
    init(renderBackend: RenderBackend) {
        self.camera = Camera(projection: .identity, view: .identity)
        self.renderBackend = renderBackend
    }
    
    func setCamera(_ projection: Transform3D, view: Transform3D) {
        self.camera.projection = projection
        self.camera.view = view
    }
    
}
