//
//  CameraEntity.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/10/23.
//

public final class CameraEntity: Entity {
    
    public var camera: Camera {
        get {
            self.components[Camera.self]!
        }
        
        set {
            self.components[Camera.self] = newValue
        }
    }
    
    public override init(name: String = "CameraEntity") {
        super.init(name: name)
        
        let camera = Camera()
        camera.isActive = true
        self.components += camera
        self.components += VisibleEntities(entities: [])
    }
    
    public init(name: String = "CameraEntity", camera: Camera) {
        super.init(name: name)
        
        var camera = camera
        camera.isActive = true
        self.components += camera
        self.components += VisibleEntities(entities: [])
    }
}
