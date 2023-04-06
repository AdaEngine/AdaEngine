//
//  OrthographicCamera.swift
//  AdaEngine
//
//  Created by v.prusakov on 4/5/23.
//

/// A virtual camera that establishes the rendering orthographic.
public final class OrthographicCamera: Entity {
    
    /// A camera component for the orthographic camera entity.
    public var camera: Camera {
        get {
            self.components[Camera.self]!
        }
        
        set {
            self.components[Camera.self] = newValue
        }
    }
    
    public override init(name: String = "OrthographicCamera") {
        super.init(name: name)
        
        let camera = Camera()
        camera.isActive = true
        camera.projection = .orthographic
        self.components += camera
        self.components += VisibleEntities()
        self.components += GlobalViewUniform()
        self.components += GlobalViewUniformBufferSet()
        self.components += RenderItems<Transparent2DRenderItem>()
    }
    
    public init(name: String = "OrthographicCamera", camera: Camera) {
        super.init(name: name)
        
        let camera = camera
        camera.isActive = true
        camera.projection = .orthographic
        self.components += camera
        self.components += GlobalViewUniform()
        self.components += GlobalViewUniformBufferSet()
        self.components += VisibleEntities()
        self.components += RenderItems<Transparent2DRenderItem>()
    }
}
