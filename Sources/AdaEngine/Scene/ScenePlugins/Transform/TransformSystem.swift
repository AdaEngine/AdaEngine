//
//  TransformSystem.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/5/24.
//

import Math

public struct TransformSystem: System {
    
    public static var dependencies: [SystemDependency] = [
        .after(Physics2DSystem.self)
    ]
    
    static let query = EntityQuery(where: .has(Transform.self))
    
    public init(scene: Scene) { }
    
    public func update(context: UpdateContext) {
        context.scene.performQuery(Self.query).forEach { entity in
            if entity.components.isComponentChanged(Transform.self) || !entity.components.has(GlobalTransform.self) {
                let transform = entity.components[Transform.self]!
                
                let matrix = Transform3D(
                    translation: transform.position,
                    rotation: transform.rotation,
                    scale: transform.scale
                )
                
                let globalTransform = GlobalTransform(matrix: matrix)
                entity.components += globalTransform
            }
        }
    }
}

// FIXME: Child transform doesn't works correctly.

public struct ChildTransformSystem: System {
    
    public static var dependencies: [SystemDependency] = [
        .after(TransformSystem.self)
    ]
    
    static let query = EntityQuery(where: .has(Transform.self) && .has(RelationshipComponent.self))
    
    public init(scene: Scene) { }
    
    public func update(context: UpdateContext) {
//        context.scene.performQuery(Self.query).forEach { entity in
//            guard entity.components.isComponentChanged(Transform.self) && !entity.children.isEmpty else {
//                return
//            }
//            
//            let transform = entity.components[GlobalTransform.self]!
//            
//            for child in entity.children {
//                guard let childTransform = child.components[GlobalTransform.self] else {
//                    continue
//                }
//                
//                let newMatrix = childTransform.matrix * transform.matrix
//                let newTransform = Transform(matrix: newMatrix)
//                child.components += newTransform
//            }
//        }
    }
}
