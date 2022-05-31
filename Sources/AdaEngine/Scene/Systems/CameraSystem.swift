//
//  CameraSystem.swift
//  
//
//  Created by v.prusakov on 5/7/22.
//

struct CameraSystem: System {
    
    static var dependencies: [SystemDependency] = [.after(ScriptComponentUpdateSystem.self)]
    
    static let query = EntityQuery(where: .has(Camera.self) && .has(Transform.self))
    
    init(scene: Scene) { }
    
    func update(context: UpdateContext) {
        context.scene.performQuery(Self.query).forEach { entity in
            guard let camera = entity.components[Camera.self] else {
                return
            }
            
            if camera.viewportSize != context.scene.viewportSize {
                camera.viewportSize = context.scene.viewportSize
            }
            
            if !camera.isCurrent && camera.isPrimal {
                context.scene.activeCamera = camera
            }
        }
    }
}
