//
//  VisibleEntities.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/6/23.
//

import AdaECS
import AdaTransform
import Math

// TODO: (Vlad) add sphere supports

/// System for detect wich entities is visible on camera.
/// All cameras has frustum and each entity should has ``BoundingComponent`` to be detected.
/// If entity doesn't has ``BoundingComponent`` than system tries to add it.
/// If entity has ``NoFrustumCulling`` than it will ignore frustum culling.
@System(dependencies: [
    .after(CameraSystem.self)
])
public struct VisibilitySystem {
    
    @EntityQuery(where: .has(VisibleEntities.self) && .has(Camera.self))
    private var cameras
    
    
    @EntityQuery(
        where: .has(Transform.self) && .has(Visibility.self)
        && .has(BoundingComponent.self) && .without(NoFrustumCulling.self)
    )
    private var entities
    
    @EntityQuery(
        where: .has(Transform.self) && .has(Visibility.self) && .has(NoFrustumCulling.self)
    )
    private var entitiesWithNoFrustum
    
    @EntityQuery(
        where: .has(Transform.self) && .without(Visibility.self)
    )
    private var entitiesWithoutVisibility
    
    public init(world: World) { }
    
    public func update(context: UpdateContext) {
        self.addVisibilityIfNeeded()
        
        self.cameras.forEach { entity in
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
    
    private func addVisibilityIfNeeded() {
        self.entitiesWithoutVisibility.forEach { entity in
            entity.components += Visibility.visible
        }
    }
    
    /// Filter entities for passed camera.
    private func filterVisibileEntities(context: UpdateContext, for camera: Camera) -> ([Entity], Set<Entity.ID>) {
        let frustum = camera.computedData.frustum
        var entityIds = Set<Entity.ID>()
        let filtredEntities = self.entities.filter { entity in
            let (bounding, visibility) = entity.components[BoundingComponent.self, Visibility.self]
            
            if visibility == .hidden {
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
        
        let withNoFrustumEntities = self.entitiesWithNoFrustum.filter { entity in
            let visibility = entity.components[Visibility.self]!
            
            if visibility != .hidden {
                entityIds.insert(entity.id)
                return true
            }
            
            return false
        }
        let entities = filtredEntities + withNoFrustumEntities
        return (entities, entityIds)
    }
}
