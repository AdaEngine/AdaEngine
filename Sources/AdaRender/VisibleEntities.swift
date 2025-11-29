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

    @FilterQuery<Entity, Visibility, BoundingComponent, With<Transform>>
    private var entities

    public init(world: World) { }

    public func update(context: UpdateContext) {
        self.cameras.forEach { camera, visibleEntities in
            if !camera.isActive {
                return
            }

            let frustum = camera.computedData.frustum
            var entityIds = Set<Entity.ID>()
            var entities: [Entity] = []
            self.entities.forEach { entity, visibility, bounding in
                if visibility == .hidden {
                    return
                }
                switch bounding.bounds {
                case .aabb(let aabb):
                    if !frustum.intersectsAABB(aabb) {
                        return
                    }
                    entityIds.insert(entity.id)
                    entities.append(entity)
                }
            }
            visibleEntities.entities = entities
            visibleEntities.entityIds = entityIds
        }
    }
}
