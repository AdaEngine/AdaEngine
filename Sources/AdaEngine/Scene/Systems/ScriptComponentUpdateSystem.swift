//
//  ScriptComponentUpdateSystem.swift
//  
//
//  Created by v.prusakov on 5/7/22.
//

struct ScriptComponentUpdateSystem: System {
    init(scene: Scene) { }
    
    func update(context: UpdateContext) {
        context.scene.entities.forEach { entity in
            for component in entity.components.buffer.values {
                
                guard let component = component as? ScriptComponent else { continue }
                
                if !component.isAwaked {
                    component.ready()
                    component.isAwaked = true
                }
                
                component.update(context.deltaTime)
            }
        }
    }
}

struct CameraSystem: System {
    
    static let query = EntityQuery((
        .has(Camera.self) || .has(EditorCamera.self)) && .has(Transform.self)
    )
    
    init(scene: Scene) { }
    
    func update(context: UpdateContext) {
        context.scene.performQuery(Self.query).forEach { entity in
            guard let camera = entity.components[Camera.self] ?? entity.components[EditorCamera.self] else {
                return
            }
            
            if !camera.isCurrent && camera.isPrimal {
                CameraManager.shared.setCurrentCamera(camera)
            }
        }
    }
}
