//
//  VisibleEntities.swift
//  
//
//  Created by v.prusakov on 2/6/23.
//

// TODO: (Vlad) add sphere supports

// This system add frustum culling for cameras.
struct VisibilitySystem: System {
    
    static var dependencies: [SystemDependency] = [.after(CameraSystem.self)]
    
    static let cameras = EntityQuery(where: .has(VisibleEntities.self) && .has(Camera.self))
    static let entities = EntityQuery(
        where: .has(Transform.self) && .has(Visibility.self) && .has(BoundingComponent.self) && .without(NoFrustumCulling.self)
    )
    
    static let entitiesWithNoFrustum = EntityQuery(
        where: .has(Transform.self) && .has(Visibility.self) && .has(NoFrustumCulling.self)
    )
    
    static let entitiesWithTransform = EntityQuery(
        where: .has(Transform.self) && .without(NoFrustumCulling.self)
    )
    
    init(scene: Scene) { }
    
    func update(context: UpdateContext) {
        
        self.updateBoundings(context: context)
        
        context.scene.performQuery(Self.cameras).forEach { entity in
            var (camera, visibleEntities) = entity.components[Camera.self, VisibleEntities.self]
            
            if !camera.isActive {
                return
            }
            
            let (filtredEntities, entityIds) = self.filterVisibileEntities(context: context, for: camera)
            visibleEntities.entities = filtredEntities
            visibleEntities.entityIds = entityIds
            entity.components[VisibleEntities.self] = visibleEntities
        }
    }
    
    // Update or create bounding boxes.
    private func updateBoundings(context: UpdateContext) {
        context.scene.performQuery(Self.entitiesWithTransform).forEach { entity in
            
            var bounds: BoundingComponent.Bounds?
            
            if entity.components.has(SpriteComponent.self) || entity.components.has(Circle2DComponent.self) {
                let transform = entity.components[Transform.self]!
                
                let position = transform.position
                let scale = transform.scale
                
                let min = Vector3(position.x - scale.x / 2, position.y - scale.y / 2, 0)
                let max = Vector3(position.x + scale.x / 2, position.y + scale.y / 2, 0)
                
                bounds = .aabb(AABB(min: min, max: max))
            }
            
            if let bounds {
                entity.components += BoundingComponent(bounds: bounds)
            }
        }
    }
    
    private func filterVisibileEntities(context: UpdateContext, for camera: Camera) -> ([Entity], Set<Entity.ID>) {
        let frustum = camera.computedData.frustum
        
        var entityIds = Set<Entity.ID>()
        
        var filtredEntities = context.scene.performQuery(Self.entities).filter { entity in
            let (bounding, visibility) = entity.components[BoundingComponent.self, Visibility.self]
            
            if !visibility.isVisible {
                return false
            }
            
            switch bounding.bounds {
            case .aabb(let aabb):
                let isIntersect = frustum.intersectsAABB(aabb)
                
                if isIntersect {
                    entityIds.insert(entity.id)
                }
                
                return isIntersect
            }
        }
        
        var withNoFrustumEntities = context.scene.performQuery(Self.entitiesWithNoFrustum).filter { entity in
            let visibility = entity.components[Visibility.self]!
            
            if visibility.isVisible {
                entityIds.insert(entity.id)
                return true
            }
            
            return false
        }
        
        let entities = filtredEntities + withNoFrustumEntities
        
        return (entities, entityIds)
    }
}
