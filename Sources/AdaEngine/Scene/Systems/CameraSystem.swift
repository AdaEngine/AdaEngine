//
//  CameraSystem.swift
//  
//
//  Created by v.prusakov on 5/7/22.
//

// TODO: Currently we render on window directly

/// System for updating a ``Camera`` data like projection matrix or frustum.
struct CameraSystem: System {
    
    static var dependencies: [SystemDependency] = [.after(ScriptComponentUpdateSystem.self)]
    
    static let query = EntityQuery(where: .has(Camera.self) && .has(Transform.self))
    
    init(scene: Scene) { }
    
    func update(context: UpdateContext) {
        context.scene.performQuery(Self.query).forEach { entity in
            guard var camera = entity.components[Camera.self] else {
                return
            }
            
            let transform = context.scene.worldTransformMatrix(for: entity)
            let viewMatrix = transform.inverse
            camera.viewMatrix = viewMatrix
            
            self.updateViewportSizeIfNeeded(for: &camera, window: context.scene.window)
            self.updateProjectionMatrix(for: &camera)
            self.updateFrustum(for: &camera)
            
            entity.components[ViewUniform.self] = ViewUniform(
                projectionMatrix: camera.computedData.projectionMatrix,
                viewProjectionMatrix: camera.computedData.projectionMatrix * viewMatrix,
                viewMatrix: camera.viewMatrix
            )
            
            entity.components[Camera.self] = camera
        }
    }
    
    private func updateViewportSizeIfNeeded(for camera: inout Camera, window: Window?) {
        switch camera.renderTarget {
        case .window(let id):
            
            if id != window?.id {
                camera.renderTarget = .window(window?.id ?? .empty)
            }
            
            let windowSize = window?.frame.size ?? .zero
            
            if camera.viewport == nil {
                camera.viewport = Viewport(rect: Rect(origin: .zero, size: windowSize))
                return
            }
            
            if camera.viewport?.rect.size != windowSize {
                camera.viewport?.rect.size = windowSize
            }
        case .texture:
            return
        }
    }
    
    private func updateFrustum(for camera: inout Camera) {
        camera.computedData.frustum = Frustum.make(from: camera.computedData.projectionMatrix * camera.viewMatrix)
    }
    
    // TODO: Not efficient?
    private func updateProjectionMatrix(for camera: inout Camera) {
        let viewportSize = camera.viewport?.rect.size ?? .zero
        
        let projection: Transform3D
        let aspectRation = viewportSize.width / viewportSize.height
        
        let scale = camera.orthographicScale
        let near = camera.near
        let far = camera.far
        
        switch camera.projection {
        case .orthographic:
            projection = Transform3D.orthographic(
                left: -aspectRation * scale,
                right: aspectRation * scale,
                top: scale,
                bottom: -scale,
                zNear: near,
                zFar: far
            )
        case .perspective:
            projection = Transform3D.perspective(
                fieldOfView: camera.fieldOfView,
                aspectRatio: aspectRation,
                zNear: near,
                zFar: far
            )
        }
        
        camera.computedData.projectionMatrix = projection
    }
}

struct ExtractCameraSystem: System {
    
    static var dependencies: [SystemDependency] = [.after(CameraSystem.self)]
    
    static let query = EntityQuery(where: .has(Camera.self) && .has(Transform.self) && .has(VisibleEntities.self))
    
    init(scene: Scene) { }
    
    func update(context: UpdateContext) {
        context.scene.performQuery(Self.query).forEach { entity in
            let cameraEntity = EmptyEntity()
            
            cameraEntity.components = entity.components
            cameraEntity.components.entity = cameraEntity
            context.renderWorld.addEntity(cameraEntity)
        }
    }
}

