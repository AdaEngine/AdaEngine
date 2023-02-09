//
//  VisibleEntities.swift
//  
//
//  Created by v.prusakov on 2/6/23.
//

public struct VisibleEntities: Component {
    public var entities: [Entity]
}

public struct Visibility: Component {
    public var isVisible: Bool = false
}

public struct BoundingComponent: Component {
    
    public enum Bounds: Codable {
        case aabb(AABB)
    }
    
    var bounds: Bounds
}

public struct NoFrustumCulling: Component { }

struct VisibilitySystem: System {
    
    static let visibleEntities = EntityQuery(where: .has(VisibleEntities.self))
    static let entities = EntityQuery(where: .has(Transform.self) && .has(Visibility.self) && .has(BoundingComponent.self))
    static let withoutBounding = EntityQuery(
        where: .has(Transform.self) && .without(BoundingComponent.self) && .without(NoFrustumCulling.self)
    )
    
    init(scene: Scene) { }
    
    func update(context: UpdateContext) {
        
        let camera = context.scene.activeCamera
        
//        self.updateBoundings(context: context)

//        var filtredEntities = self.filterVisibileEntities(context: context)
//        context.scene.performQuery(Self.visibleEntities).forEach { entity in
//            var visibleEntities = entity.components[VisibleEntities.self]!
//            visibleEntities.entities = filtredEntities
//            entity.components[VisibleEntities.self] = visibleEntities
//        }
    }
    
    private func updateBoundings(context: UpdateContext) {
        context.scene.performQuery(Self.withoutBounding).forEach { entity in
            
            var bounds: BoundingComponent.Bounds?
            
            if entity.components.has(SpriteComponent.self) || entity.components.has(Circle2DComponent.self) {
                
                let transform = entity.components[Transform.self]!
                
                let position = transform.position
                let scale = transform.scale
                
                let min = Vector3(position.x - scale.x / 2, position.y - scale.y / 2, -1)
                let max = Vector3(position.x + scale.x / 2, position.y + scale.y / 2, 1)
                
                bounds = .aabb(AABB(min: min, max: max))
            }
            
            if let bounds {
//                entity.components += BoundingComponent(bounds: bounds)
            }
            
        }
    }
    
    private func filterVisibileEntities(context: UpdateContext) -> [Entity] {
        context.scene.performQuery(Self.entities).filter { _ in
            return true
        }
    }
}
