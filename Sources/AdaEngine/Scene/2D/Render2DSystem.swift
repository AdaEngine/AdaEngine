//
//  Render2DSystem.swift
//  
//
//  Created by v.prusakov on 5/10/22.
//

struct Render2DSystem: System {
    
    static var dependencies: [SystemDependency] = [.after(ViewContainerSystem.self)]
    
    static let spriteQuery = EntityQuery(where: (.has(Circle2DComponent.self) || .has(SpriteComponent.self)) && .has(Transform.self))
    
    init(scene: Scene) { }
    
    func update(context: UpdateContext) {
        let render2D = context.scene.sceneRenderer.renderer2D
        let spriteEntities = context.scene.performQuery(Self.spriteQuery)
        
        guard !spriteEntities.isEmpty else { return }
        
        guard let window = context.scene.window else {
            return
        }
        
        let drawContext = render2D.beginContext(for: window.id, camera: context.scene.activeCamera)
        drawContext.setDebugName("Start 2D Rendering scene")
        
        spriteEntities.forEach { entity in
            guard let transform = entity.components[Transform.self] else {
                assert(true, "Render 2D System don't have required Transform component")
                
                return
            }
            
            if let circle = entity.components[Circle2DComponent.self] {
                drawContext.drawCircle(
                    transform: transform.matrix,
                    thickness: circle.thickness,
                    fade: circle.fade,
                    color: circle.color
                )
            }
            
            if let sprite = entity.components[SpriteComponent.self] {
                drawContext.drawQuad(
                    transform: transform.matrix,
                    texture: sprite.texture,
                    color: sprite.tintColor
                )
            }
        }
        
        drawContext.commitContext()
    }
}
