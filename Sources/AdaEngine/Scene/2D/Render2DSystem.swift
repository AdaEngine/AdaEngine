//
//  Render2DSystem.swift
//  
//
//  Created by v.prusakov on 5/10/22.
//

struct Render2DSystem: System {
    
    static var dependencies: [SystemDependency] = [.before(Physics2DSystem.self)]
    
    static let spriteQuery = EntityQuery(
        where: (.has(Circle2DComponent.self) || .has(SpriteComponent.self)) && .has(Transform.self)
    )
    
    init(scene: Scene) { }
    
    func update(context: UpdateContext) {
        let render2D = context.scene.sceneRenderer.renderer2D
        let spriteEntities = context.scene.performQuery(Self.spriteQuery)
        
        guard !spriteEntities.isEmpty else { return }
        
        let drawContext = render2D.beginContext(for: context.scene.activeCamera)
        drawContext.setDebugName("Start 2D Rendering scene")
        
        spriteEntities.forEach { entity in
            guard let matrix = entity.components[Transform.self]?.matrix else {
                assert(true, "Render 2D System don't have required Transform component")
                
                return
            }
            
            if let bounding = entity.components[BoundingComponent.self] {
                switch bounding.bounds {
                case .aabb(let aabb):
                    
                    let position: Vector3 = [aabb.max.x / 2, aabb.max.y / 2, 1]
                    let size: Vector2 = [aabb.min.x + aabb.max.x, aabb.min.y + aabb.max.y]
                    
                    drawContext.drawQuad(
                        position: position,
                        size: size,
                        color: .red.opacity(0.2)
                    )
                }
            }
            
            if let circle = entity.components[Circle2DComponent.self] {
                drawContext.drawCircle(
                    transform: matrix,
                    thickness: circle.thickness,
                    fade: circle.fade,
                    color: circle.color
                )
            }
            
            if let sprite = entity.components[SpriteComponent.self] {
                drawContext.drawQuad(
                    transform: matrix,
                    texture: sprite.texture,
                    color: sprite.tintColor
                )
            }
        }
        
        drawContext.commitContext()
    }
}
