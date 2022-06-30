//
//  Circle2DRenderSystem.swift
//  
//
//  Created by v.prusakov on 5/10/22.
//

struct Render2DSystem: System {
    
    static var dependencies: [SystemDependency] = [.after(ViewContainerSystem.self)]
    
    static let spriteQuery = EntityQuery(where: (.has(Circle2DComponent.self) || .has(SpriteComponent.self)) && .has(Transform.self))
    
    init(scene: Scene) { }
    
    func update(context: UpdateContext) {
        let spriteEntities = context.scene.performQuery(Self.spriteQuery)
        
        guard !spriteEntities.isEmpty else { return }
        
        guard let window = context.scene.window else {
            return
        }
        
        RenderEngine2D.shared.beginContext(for: window.id, camera: context.scene.activeCamera)
        RenderEngine2D.shared.setDebugName("Start 2D Rendering scene")
        
        spriteEntities.forEach { entity in
            guard let transform = entity.components[Transform.self] else {
                assert(true, "Render 2D System don't have required Transform component")
                
                return
            }
            
            if let circle = entity.components[Circle2DComponent.self] {
                RenderEngine2D.shared.drawCircle(
                    transform: transform.matrix,
                    thickness: circle.thickness,
                    fade: circle.fade,
                    color: circle.color
                )
            }
            
            if let sprite = entity.components[SpriteComponent.self] {
                RenderEngine2D.shared.drawQuad(
                    transform: transform.matrix,
                    texture: sprite.texture,
                    color: sprite.tintColor
                )
            }
        }
        
        RenderEngine2D.shared.commitContext()
    }
}
