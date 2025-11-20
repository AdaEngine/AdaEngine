//
//  TransformSystem.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/5/24.
//

import AdaECS
import Math

/// A system that updates the global transform of the entity.
@PlainSystem
public struct TransformSystem {
    
    @FilterQuery<Entity, Transform, Or<Changed<Transform>, Without<GlobalTransform>>>
    private var query

    @Commands
    private var commands

    public init(world: World) { }
    
    public func update(context: inout UpdateContext) {
        self.query.forEach { entity, transform in
            let globalTransform = GlobalTransform(matrix: transform.matrix)
            commands.entity(entity.id)
                .insert(globalTransform)
        }
    }
}

/// A system that updates the global transform of the children of the entity.
@PlainSystem(dependencies: [
    .after(TransformSystem.self)
])
public struct ChildTransformSystem {
    
    @FilterQuery<Entity, GlobalTransform, Changed<Transform>>
    private var query

    @Commands
    private var commands

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
            guard child.components.has(Transform.self) else {
                continue
            }

            let childTransform = child.components.get(Transform.self)
            let newMatrix = parentTransform.matrix * childTransform.matrix
            commands.entity(child.id).insert(GlobalTransform(matrix: newMatrix))
            
            if !child.children.isEmpty {
                updateChildren(child.children, parentTransform: GlobalTransform(matrix: newMatrix))
            }
        }
    }
}
