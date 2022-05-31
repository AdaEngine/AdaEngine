//
//  Circle2DRenderSystem.swift
//  
//
//  Created by v.prusakov on 5/10/22.
//

import Foundation

struct Circle2DRenderSystem: System {
    
    static var dependencies: [SystemDependency] = [.after(ViewContainerSystem.self)]
    
    static let query = EntityQuery(where: .has(Circle2DComponent.self) && .has(Transform.self))
    
    init(scene: Scene) { }
    
    func update(context: UpdateContext) {
        
        let entities = context.scene.performQuery(Self.query)
        
        guard !entities.isEmpty else { return }
        
        guard let window = context.scene.window else {
            return
        }
        
        RenderEngine2D.shared.beginContext(for: window.id, camera: context.scene.activeCamera)
        RenderEngine2D.shared.setDebugName("Circle2D Rendering")
        
        entities.forEach { entity in
            let (circle, transform) = entity.components[Circle2DComponent.self, Transform.self]
            
            RenderEngine2D.shared.drawCircle(
                transform: transform.matrix,
                thickness: circle.thickness,
                fade: circle.fade,
                color: circle.color
            )
        }
        
        RenderEngine2D.shared.commitContext()
    }
}
