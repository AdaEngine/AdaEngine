//
//  VisibleEntities.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/6/23.
//

import AdaECS
import AdaTransform
import Math
import AdaUtils

// TODO: (Vlad) add sphere supports

/// System for detect wich entities is visible on camera.
/// All cameras has frustum and each entity should has ``BoundingComponent`` to be detected.
/// If entity doesn't has ``BoundingComponent`` than system tries to add it.
/// If entity has ``NoFrustumCulling`` than it will ignore frustum culling.
@PlainSystem(dependencies: [
    .after(CameraSystem.self)
])
public struct VisibilitySystem {

    @Query<Camera, Ref<VisibleEntities>>
    private var cameras
    
    @FilterQuery<Entity, Visibility, BoundingComponent, And<With<Transform>, Without<NoFrustumCulling>>>
    private var entities

    @FilterQuery<Entity, Visibility, And<With<Transform>, With<NoFrustumCulling>>>
    private var entitiesWithNoFrustum

    @FilterQuery<Entity, And<With<Transform>, Without<Visibility>>>
    private var entitiesWithoutVisibility
    
    public init(world: World) { }

    public func update(context: inout UpdateContext) {
        self.cameras.forEach { camera, visibleEntities in
            if !camera.isActive {
                return
            }
            
            let (filtredEntities, entityIds) = self.filterVisibileEntities(context: context, for: camera)
            visibleEntities.entities = filtredEntities
            visibleEntities.entityIds = entityIds
        }
    }
    
    /// Filter entities for passed camera.
    private func filterVisibileEntities(
        context: borrowing UpdateContext, 
        for camera: Camera
    ) -> (entities: [Entity], entityIds: Set<Entity.ID>) {
        let frustum = camera.computedData.frustum
        var entityIds = Set<Entity.ID>()
        let filtredEntities: [Entity] = self.entities.compactMap { entity, visibility, bounding in
            if visibility == .hidden {
                return nil
            }
            switch bounding.bounds {
            case .aabb(let aabb):
                let isIntersect = frustum.intersectsAABB(aabb)
                
                if isIntersect {
                    entityIds.insert(entity.id)
                }
                
                return isIntersect ? entity : nil
            }
        }
        
        let withNoFrustumEntities: [Entity] = self.entitiesWithNoFrustum.compactMap { entity, visibility in
            if visibility != .hidden {
                entityIds.insert(entity.id)
                return entity
            }
            return nil
        }
        let entities = filtredEntities + withNoFrustumEntities
        return (entities, entityIds)
    }
}
