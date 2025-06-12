//
//  TransformSystem.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/5/24.
//

import AdaECS
import Math

/// A system that updates the global transform of the entity.
@System
public struct TransformSystem {
    
    @EntityQuery(where: .has(Transform.self))
    private var query
    
    public init(world: World) { }
    
    public func update(context: inout UpdateContext) {
        self.query.forEach { entity in
            if entity.components.isComponentChanged(Transform.self)
                || !entity.components.has(GlobalTransform.self)
            {
                guard let transform = entity.components[Transform.self] else {
                    return
                }
                let globalTransform = GlobalTransform(matrix: transform.matrix)
                entity.components += globalTransform
            }
        }
    }
}

/// A system that updates the global transform of the children of the entity.
@System(dependencies: [
    .after(TransformSystem.self)
])
public struct ChildTransformSystem {
    
    @EntityQuery(where: .has(Transform.self))
    private var query
    
    public init(world: World) { }
    
    public func update(context: inout UpdateContext) {
        self.query.forEach { entity in
            guard entity.components.isComponentChanged(Transform.self) && !entity.children.isEmpty else {
                return
            }
            
            updateChildren(entity.children, parentTransform: entity.components[GlobalTransform.self]!)
        }
    }
    
    /// Update the children of the entity.
    ///
    /// - Parameter children: The children of the entity.
    /// - Parameter parentTransform: The parent transform of the entity.
    private func updateChildren(_ children: [Entity], parentTransform: GlobalTransform) {
        for child in children {
            guard let childTransform = child.components[Transform.self] else {
                continue
            }
            
            let newMatrix = parentTransform.matrix * childTransform.matrix
//            child.components += Transform(matrix: newMatrix)
            child.components += GlobalTransform(matrix: newMatrix)
            
            if !child.children.isEmpty {
                updateChildren(child.children, parentTransform: GlobalTransform(matrix: newMatrix))
            }
        }
    }
}
