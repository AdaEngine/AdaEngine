//
//  RenderEngine.swift
//  
//
//  Created by v.prusakov on 10/25/21.
//

public class RenderEngine {
    
    public static var shared: RenderEngine!
    
    public enum BackendType: UInt {
        case metal
        case vulkan
    }
    
    public let backendType: BackendType
    
    public let renderBackend: RenderBackend
    
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
            renderBackend = try VulkanRenderBackend(appName: appName)
        }
        
        let renderEngine = RenderEngine(backendType: backendType, renderBackend: renderBackend)
        Self.shared = renderEngine
        
        return renderEngine
    }
    
    // MARK: Methods
    
    public func draw() throws {
        try self.renderBackend.beginFrame()
        
        try self.renderBackend.endFrame()
    }
    
    public func initialize(for view: RenderView, size: Vector2i) throws {
        try self.renderBackend.createWindow(for: view, size: size)
    }
    
    public func updateViewSize(newSize: Vector2i) throws {
        try self.renderBackend.resizeWindow(newSize: newSize)
    }
    
    // MARK: Buffers
    
    public func makeRenderBuffer(length: Int) -> RenderBuffer {
        return RenderBuffer(byteCount: length)
    }
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
    
    func renderScene(renderBuffers: RenderBuffer) {
        
    }
    
}
