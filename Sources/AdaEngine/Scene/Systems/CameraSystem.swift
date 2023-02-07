//
//  CameraSystem.swift
//  
//
//  Created by v.prusakov on 5/7/22.
//

struct CameraSystem: System {
    
    static var dependencies: [SystemDependency] = [.after(ScriptComponentUpdateSystem.self)]
    
    static let query = EntityQuery(where: .has(Camera.self))
    
    init(scene: Scene) { }
    
    func update(context: UpdateContext) {
        context.scene.performQuery(Self.query).forEach { entity in
            guard let camera = entity.components[Camera.self] else {
                return
            }
            
            let sceneViewport = context.scene.viewport
            
            self.updateFrustum(for: camera, entity: entity, scene: context.scene)
            
            if camera.isActive && sceneViewport?.camera !== camera {
                
                camera.viewport = sceneViewport // Should we set a viewport in the system??
                sceneViewport?.camera = camera
                
                context.scene.activeCamera = camera
            }
        }
    }
    
    private func updateFrustum(for camera: Camera, entity: Entity, scene: Scene) {
        let viewMatrix = scene.worldTransformMatrix(for: entity).inverse
        camera.frustum = Frustum.make(from: camera.projectionMatrix * viewMatrix)
    }
}
