//
//  CameraSystem.swift
//  
//
//  Created by v.prusakov on 5/7/22.
//

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
            
            if camera.viewportSize == .zero {
                camera.viewportSize = RenderEngine.shared.renderBackend.viewportSize
            }
            
            if !camera.isCurrent && camera.isPrimal {
                context.scene.activeCamera = camera
            }
        }
    }
}
