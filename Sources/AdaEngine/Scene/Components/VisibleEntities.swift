//
//  VisibleEntities.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/6/23.
//

// TODO: (Vlad) add sphere supports

/// System for detect wich entities is visible on camera.
/// All cameras has frustum and each entity should has ``BoundingComponent`` to be detected.
/// If entity doesn't has ``BoundingComponent`` than system tries to add it.
/// If entity has ``NoFrustumCulling`` than it will ignore frustum culling.
public struct VisibilitySystem: System {
    
    public static var dependencies: [SystemDependency] = [.after(CameraSystem.self)]
    
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
    
    public init(scene: Scene) { }
    
    public func update(context: UpdateContext) {
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

    // FIXME: Should we calculate it here?
    /// Update or create bounding boxes for SpriteComponent and Mesh2D.
    private func updateBoundings(context: UpdateContext) {
        context.scene.performQuery(Self.entitiesWithTransform).forEach { entity in
            var bounds: BoundingComponent.Bounds?
            
            if entity.components.has(SpriteComponent.self) || entity.components.has(Circle2DComponent.self) {
                if !entity.components.isComponentChanged(Transform.self) && entity.components.has(BoundingComponent.self) {
                    return
                }
                
                let transform = entity.components[Transform.self]!

                let position = transform.position
                let scale = transform.scale
                
                let min = Vector3(position.x - scale.x / 2, position.y - scale.y / 2, 0)
                let max = Vector3(position.x + scale.x / 2, position.y + scale.y / 2, 0)
                
                bounds = .aabb(AABB(min: min, max: max))
            } else if let mesh2d = entity.components[Mesh2DComponent.self] {
                bounds = .aabb(mesh2d.mesh.bounds)
            }
            
            if let bounds {
                entity.components += BoundingComponent(bounds: bounds)
            }
        }
    }
    
    /// Filter entities for passed camera.
    private func filterVisibileEntities(context: UpdateContext, for camera: Camera) -> ([Entity], Set<Entity.ID>) {
        let frustum = camera.computedData.frustum
        var entityIds = Set<Entity.ID>()
        let filtredEntities = context.scene.performQuery(Self.entities).filter { entity in
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
        
        let withNoFrustumEntities = context.scene.performQuery(Self.entitiesWithNoFrustum).filter { entity in
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
