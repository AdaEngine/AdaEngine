//
//  Circle2DRenderSystem.swift
//  
//
//  Created by v.prusakov on 5/10/22.
//

import Foundation

struct Circle2DRenderSystem: System {
    
    static let query = EntityQuery(.has(Circle2DComponent.self) && .has(Transform.self))
    
    init(scene: Scene) { }
    
    func update(context: UpdateContext) {
        
        let entities = context.scene.performQuery(Self.query)
        
        guard !entities.isEmpty else { return }
        
        RenderEngine2D.shared.beginContext(context.scene.activeCamera)
        RenderEngine2D.shared.setDebugName("Circle2D Rendering")
        
        entities.forEach { entity in
            let (circle, transform) = entity.components[Circle2DComponent.self, Transform.self]
            
            RenderEngine2D.shared.setFillColor(circle.color)
            
            RenderEngine2D.shared.drawCircle(
                transform: transform.matrix,
                thickness: circle.thickness,
                fade: circle.fade
            )
        }
        
        RenderEngine2D.shared.commitContext()
    }
}
