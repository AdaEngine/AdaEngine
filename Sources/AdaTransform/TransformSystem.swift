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
    
    @FilterQuery<Entity, Transform, Or<Changed<Transform>, Without<GlobalTransform>>>
    private var query
    
    public init(world: World) { }
    
    public func update(context: inout UpdateContext) {
        self.query.forEach { entity, transform in
            let globalTransform = GlobalTransform(matrix: transform.matrix)
            entity.components += globalTransform
        }
    }
}

/// A system that updates the global transform of the children of the entity.
@System(dependencies: [
    .after(TransformSystem.self)
])
public struct ChildTransformSystem {
    
    @FilterQuery<Entity, GlobalTransform, Changed<Transform>>
    private var query
    
    public init(world: World) { }
    
    public func update(context: inout UpdateContext) {
        self.query.forEach { entity, globalTransform in
            guard !entity.children.isEmpty else {
                return
            }
            
            updateChildren(entity.children, parentTransform: globalTransform)
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
            child.components += GlobalTransform(matrix: newMatrix)
            
            if !child.children.isEmpty {
                updateChildren(child.children, parentTransform: GlobalTransform(matrix: newMatrix))
            }
        }
    }
}
