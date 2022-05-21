//
//  File.swift
//  
//
//  Created by v.prusakov on 5/21/22.
//

import AdaEngine
import Math

struct EditorCameraComponent: Component {
    var speed: Float = 20
    var pitch: Angle = Angle.radians(0)
    var yaw: Angle = Angle.radians(-90)
}

class EditorCameraSystem: System {
    
    static let query = EntityQuery(where: .has(EditorCameraComponent.self) && .has(Camera.self))
    
    private var cameraUp: Vector3 = Vector3(0, 1, 0)
    private var cameraFront: Vector3 = Vector3(0, 0, -1)
    
    private var lastMousePosition: Point = .zero
    
    private var isViewMatrixDirty = false
    
    required public init(scene: Scene) { }
    
    public func update(context: UpdateContext) {
        let entities = context.scene.performQuery(Self.query)
        let deltaTime = context.deltaTime
        
        for entity in entities {
            
            let (editorCamera, camera) = entity.components[EditorCameraComponent.self, Camera.self]
            let speed = editorCamera.speed
            
            if Input.isKeyPressed(.w) {
                
                camera.transform.position += speed * cameraFront * deltaTime
                self.isViewMatrixDirty = true
            }
            
            if Input.isKeyPressed(.a) {
                camera.transform.position -= cross(cameraFront, cameraUp).normalized * speed * deltaTime
                self.isViewMatrixDirty = true
            }
            
            if Input.isKeyPressed(.d) {
                camera.transform.position += cross(cameraFront, cameraUp).normalized * speed * deltaTime
                self.isViewMatrixDirty = true
            }
            
            if Input.isKeyPressed(.s) {
                camera.transform.position -= speed * cameraFront * deltaTime
                self.isViewMatrixDirty = true
            }
            
            if self.isViewMatrixDirty {
                camera.viewMatrix = Transform3D.lookAt(
                    eye: camera.transform.position,
                    center: camera.transform.position + self.cameraFront,
                    up: self.cameraUp
                )
                
                self.isViewMatrixDirty = false
            }
            
            // Apply transform
            entity.components[EditorCameraComponent.self] = editorCamera
        }
    }
    
    func mouseEvent(for editorComponent: inout EditorCameraComponent) {
        let position = Input.getMousePosition()
        var xoffset = position.x - self.lastMousePosition.x;
        var yoffset = self.lastMousePosition.y - position.y;
        self.lastMousePosition = position

        let sensitivity: Float = 0.1
        xoffset *= sensitivity
        yoffset *= sensitivity

        editorComponent.yaw   += xoffset
        editorComponent.pitch += yoffset
        
        if editorComponent.pitch.radians > 89.0 {
            editorComponent.pitch = 89.0
        } else if(editorComponent.pitch.radians < -89.0) {
            editorComponent.pitch = -89.0
        }
        
        var direction = Vector3()
        direction.x = cos(editorComponent.yaw.radians) * cos(editorComponent.pitch.radians)
        direction.y = sin(editorComponent.pitch.radians)
        direction.z = sin(editorComponent.yaw.radians) * cos(editorComponent.pitch.radians)
        
        self.cameraFront = direction.normalized
        self.isViewMatrixDirty = true
    }
}

class EditorCameraEntity: Entity {
    public override init(name: String = "Entity") {
        super.init(name: name)
        
        self.components[EditorCameraComponent.self] = EditorCameraComponent()
    }
}
