//
//  OrthographicCamera.swift
//  AdaEngine
//
//  Created by v.prusakov on 4/5/23.
//

import AdaECS
import AdaAudio
import AdaRender

/// A virtual camera that establishes the rendering orthographic.
public final class OrthographicCamera: Entity, @unchecked Sendable {

    /// A camera component for the orthographic camera entity.
    public var camera: Camera {
        get {
            self.components[Camera.self]!
        }
        
        set {
            self.components[Camera.self] = newValue
        }
    }
    
    /// Create a new orthograpich camera for rendering 2D and 3D items on screen.
    public override init(name: String = "OrthographicCamera") {
        super.init(name: name)
        
        var camera = Camera()
        camera.isActive = true
        camera.projection = .orthographic
        self.components += camera
        self.components += VisibleEntities()
        self.components += GlobalViewUniform()
        self.components += GlobalViewUniformBufferSet()
        self.components += AudioReceiver()
        self.components += Transform()
    }
    
    /// Create a new orthograpich camera for rendering 2D and 3D items on screen.
    public init(name: String = "OrthographicCamera", camera: Camera) {
        super.init(name: name)
        
        var camera = camera
        camera.isActive = true
        camera.projection = .orthographic
        self.components += camera
        self.components += GlobalViewUniform()
        self.components += GlobalViewUniformBufferSet()
        self.components += VisibleEntities()
    }
}
