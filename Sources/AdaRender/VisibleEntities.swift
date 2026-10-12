//
//  VisibleEntities.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/6/23.
//

import AdaECS
import AdaTransform
import AdaUtils
import Math

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

    @Query<Entity, Visibility, BoundingComponent, GlobalTransform>
    private var entities

    public init(world _: World) {}

    public func update(context _: UpdateContext) {
        self.cameras.forEach { camera, visibleEntities in
            if !camera.isActive {
                return
            }

            let frustum = camera.computedData.frustum
            // Previous frame's count is a good estimate; avoids repeated rehash/regrow.
            let expectedCount = visibleEntities.entities.count
            var entityIds = Set<Entity.ID>(minimumCapacity: expectedCount)
            var entities: [Entity] = []
            entities.reserveCapacity(expectedCount)
            self.entities.forEach { entity, visibility, bounding, globalTransform in
                if visibility == .hidden {
                    return
                }
                if entity.components.has(NoFrustumCulling.self) {
                    entityIds.insert(entity.id)
                    entities.append(entity)
                    return
                }
                switch bounding.bounds {
                case let .aabb(aabb):
                    if !frustum.intersectsAABB(aabb.transformed(by: globalTransform.matrix)) {
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

extension AABB {
    func transformed(by transform: Transform3D) -> AABB {
        // Arvo's method: transform the center and project the half extents through the absolute matrix.
        let newCenter = (transform * Vector4(center, 1)).xyz
        let c0 = transform[0]
        let c1 = transform[1]
        let c2 = transform[2]
        let newHalfExtents = Vector3(
            abs(c0.x) * halfExtents.x + abs(c1.x) * halfExtents.y + abs(c2.x) * halfExtents.z,
            abs(c0.y) * halfExtents.x + abs(c1.y) * halfExtents.y + abs(c2.y) * halfExtents.z,
            abs(c0.z) * halfExtents.x + abs(c1.z) * halfExtents.y + abs(c2.z) * halfExtents.z
        )
        return AABB(center: newCenter, halfExtents: newHalfExtents)
    }
}
