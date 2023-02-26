//
//  DebugPhysics2DSystem.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/26/23.
//

import Foundation

struct DebugPhysics2DSystem: System {
    
    static var dependencies: [SystemDependency] = [.after(Physics2DSystem.self)]
//
//    static let entities = EntityQuery(
//        where: .has(PhysicsBody2DComponent.self) || .has(Collision2DComponent.self) || .has(PhysicsJoint2DComponent.self),
//        filter: .removed
//    )
    
    static let cameras = EntityQuery(where:
            .has(Camera.self) &&
            .has(VisibleEntities.self) &&
            .has(RenderItems<Transparent2DRenderItem>.self)
    )
    
    init(scene: Scene) { }
    
    func update(context: UpdateContext) {
        guard context.scene.debugOptions.contains(.showPhysicsShapes) else {
            return
        }
        
        context.scene.performQuery(Self.cameras).forEach { entity in
            var (camera, visibleEntities, renderItems) = entity.components[Camera.self, VisibleEntities.self, RenderItems<Transparent2DRenderItem>.self]
            
            if !camera.isActive {
                return
            }
            
            self.draw(
                scene: context.scene,
                visibleEntities: visibleEntities.entities,
                renderItems: &renderItems
            )
            
            entity.components += renderItems
        }
    }
    
    private func draw(scene: Scene, visibleEntities: [Entity], renderItems: inout RenderItems<Transparent2DRenderItem>) {
        
    }
}
