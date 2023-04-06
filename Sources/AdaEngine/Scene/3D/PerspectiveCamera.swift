//
//  PerspectiveCamera.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/10/23.
//

/// A virtual camera that establishes the rendering perspective.
public final class PerspectiveCamera: Entity {
    
    /// A camera component for the perspective camera entity.
    public var camera: Camera {
        get {
            self.components[Camera.self]!
        }
        
        set {
            self.components[Camera.self] = newValue
        }
    }
    
    public override init(name: String = "PerspectiveCamera") {
        super.init(name: name)
        
        let camera = Camera()
        camera.isActive = true
        camera.projection = .perspective
        self.components += camera
        self.components += VisibleEntities()
        self.components += GlobalViewUniform()
        self.components += GlobalViewUniformBufferSet()
        self.components += RenderItems<Transparent2DRenderItem>()
    }
    
    public init(name: String = "PerspectiveCamera", camera: Camera) {
        super.init(name: name)
        
        let camera = camera
        camera.isActive = true
        camera.projection = .perspective
        self.components += camera
        self.components += GlobalViewUniform()
        self.components += GlobalViewUniformBufferSet()
        self.components += VisibleEntities()
        self.components += RenderItems<Transparent2DRenderItem>()
    }
}
