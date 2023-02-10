//
//  Render2DSystem.swift
//  
//
//  Created by v.prusakov on 5/10/22.
//

struct Render2DSystem: System {
    
    static var dependencies: [SystemDependency] = [.before(Physics2DSystem.self)]
    
    static let cameras = EntityQuery(where: .has(Camera.self) && .has(VisibleEntities.self))
    
    init(scene: Scene) { }
    
    func update(context: UpdateContext) {
        context.scene.performQuery(Self.cameras).forEach { entity in
            let (camera, visibleEntities) = entity.components[Camera.self, VisibleEntities.self]
            
            if !camera.isActive {
                return
            }
            
            self.draw(camera: camera, entities: visibleEntities.entities, context: context)
        }
    }
    
    private func draw(camera: Camera, entities: [Entity], context: UpdateContext) {
        let renderer = context.scene.sceneRenderer.renderer2D
        let drawContext = renderer.beginContext(for: camera)
        drawContext.setDebugName("Start 2D Rendering scene")
        
        entities.forEach { entity in
            guard let matrix = entity.components[Transform.self]?.matrix else {
                assert(true, "Render 2D System don't have required Transform component")
                
                return
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
            
            if context.scene.debugOptions.contains(.showBoundingBoxes) {
                if let bounding = entity.components[BoundingComponent.self] {
                    switch bounding.bounds {
                    case .aabb(let aabb):
                        let size: Vector2 = [aabb.halfExtents.x * 2, aabb.halfExtents.y * 2]
                        
                        drawContext.drawQuad(
                            position: aabb.center,
                            size: size,
                            color: context.scene.debugPhysicsColor.opacity(0.5)
                        )
                    }
                }
            }
        }
        
        drawContext.commitContext()
    }
}
