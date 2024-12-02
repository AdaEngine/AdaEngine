//
//  EditorCamera.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/21/22.
//

import AdaEngine

@Component
struct EditorCameraComponent {
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

            var (editorCamera, camera, transform) = entity.components[EditorCameraComponent.self, Camera.self, Transform.self]
            let speed = editorCamera.speed

            if Input.isKeyPressed(.w) {
                transform.position += speed * cameraFront * deltaTime
                self.isViewMatrixDirty = true
            }

            if Input.isKeyPressed(.a) {
                transform.position -= cross(cameraFront, cameraUp).normalized * speed * deltaTime
                self.isViewMatrixDirty = true
            }

            if Input.isKeyPressed(.d) {
                transform.position += cross(cameraFront, cameraUp).normalized * speed * deltaTime
                self.isViewMatrixDirty = true
            }

            if Input.isKeyPressed(.s) {
                transform.position -= speed * cameraFront * deltaTime
                self.isViewMatrixDirty = true
            }

            if self.isViewMatrixDirty {
                camera.viewMatrix = Transform3D.lookAt(
                    eye: transform.position,
                    center: transform.position + self.cameraFront,
                    up: self.cameraUp
                )

                self.isViewMatrixDirty = false
            }

            // Apply transform
            entity.components[EditorCameraComponent.self] = editorCamera
            entity.components[Camera.self] = camera
            entity.components[Transform.self] = transform
        }
    }

    func mouseEvent(for editorComponent: inout EditorCameraComponent) {
//                let position = Input.getMousePosition()
//                var xoffset = position.x - self.lastMousePosition.x
//                var yoffset = self.lastMousePosition.y - position.y
//                self.lastMousePosition = position
//        
//                let sensitivity: Float = 0.1
//                xoffset *= sensitivity
//                yoffset *= sensitivity
//        
//                editorComponent.yaw   += xoffset
//                editorComponent.pitch += yoffset
//        
//                if editorComponent.pitch.radians > 89.0 {
//                    editorComponent.pitch = 89.0
//                } else if(editorComponent.pitch.radians < -89.0) {
//                    editorComponent.pitch = -89.0
//                }
//        
//                var direction = Vector3()
//                direction.x = Math.cos(editorComponent.yaw.radians) * Math.cos(editorComponent.pitch.radians)
//                direction.y = Math.sin(editorComponent.pitch.radians)
//                direction.z = Math.sin(editorComponent.yaw.radians) * Math.cos(editorComponent.pitch.radians)
//        
//                self.cameraFront = direction.normalized
//                self.isViewMatrixDirty = true
    }
}

class EditorCameraEntity: Entity, @unchecked Sendable {
    public override init(name: String = "Entity") {
        super.init(name: name)

        self.components += EditorCameraComponent()
        self.components += Camera()
    }
}
