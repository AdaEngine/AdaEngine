//
//  VisibleEntities.swift
//  
//
//  Created by v.prusakov on 2/6/23.
//

public struct VisibleEntities: Component {
    public var entities: [Entity]
}

struct AABBComponent: Component {
    var aabb: AABB
}

struct VisibilitySystem: System {
    
    static let visibleEntities = EntityQuery(where: .has(VisibleEntities.self))
    static let entities = EntityQuery(where: .has(Transform.self))
    static let withoutAABB = EntityQuery(where: .has(Transform.self) && .without(AABBComponent.self))
    
    init(scene: Scene) { }
    
    func update(context: UpdateContext) {
        
        let camera = context.scene.activeCamera
        
        print("Frustum", camera.frustum)
        
//        let entities = context.scene.performQuery(Self.entities)
//
//        context.scene.performQuery(Self.visibleEntities).forEach { entity in
//            var visibleEntities = entity.components[VisibleEntities.self]!
//            visibleEntities.entities.removeAll()
//
//            entity.components[VisibleEntities.self] = visibleEntities
//        }
    }
    
    private func updateAABB(context: UpdateContext) {
        context.scene.performQuery(Self.withoutAABB).forEach { entity in
            
        }
    }
}
