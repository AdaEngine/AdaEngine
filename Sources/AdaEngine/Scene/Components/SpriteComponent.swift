//
//  File.swift
//  
//
//  Created by v.prusakov on 5/8/22.
//

struct SpriteComponent: Component {
    var color: Color
}

struct Circle2DComponent: Component {
    var radius: Float
    var color: Color
}

struct Circle2DRenderSystem: System {
    
    static let query = EntityQuery(.has(Circle2DComponent.self) && .has(Transform.self))
    
    init(scene: Scene) {
        
    }
    
    func update(context: UpdateContext) {
        
        let entities = context.scene.performQuery(Self.query)
        
        guard !entities.isEmpty else { return }
        
        RenderEngine2D.shared.beginContext(context.scene.activeCamera)
        
        entities.forEach { entity in
            let circle = entity.components[Circle2DComponent.self]!
            let transform = entity.components[Transform.self]!
            
            RenderEngine2D.shared.drawCircle(
                transform: transform.matrix,
                color: circle.color,
                radius: circle.radius,
                thickness: 1,
                fade: 0.005
            )
        }
        
        RenderEngine2D.shared.commitContext()
    }
}
