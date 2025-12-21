//
//  TransformSystem.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/5/24.
//

import AdaECS
import AdaUtils
import Math

/// A system that updates the global transform of the entity.
@PlainSystem
public struct TransformSystem {
    
    @FilterQuery<
        Entity,
        Transform,
        Ref<GlobalTransform>,
        Or<
            Changed<Transform>,
            Added<Transform>
        >
    >
    private var query

    @Commands
    private var commands

    public init(world: World) { }
    
    public func update(context: UpdateContext) async {
        await self.query.parallel().forEach { entity, transform, globalTransform in
            globalTransform.wrappedValue = GlobalTransform(matrix: transform.matrix)
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
    
    public func update(context: UpdateContext) async {
        await self.query.parallel().forEach { entity, globalTransform in
            guard !entity.children.isEmpty else {
                return
            }
            
            updateChildren(entity.children, world: context.world, parentTransform: globalTransform)
        }
    }
    
    /// Update the children of the entity.
    ///
    /// - Parameter children: The children of the entity.
    /// - Parameter parentTransform: The parent transform of the entity.
    private func updateChildren(
        _ children: [Entity],
        world: World,
        parentTransform: GlobalTransform
    ) {
        for child in children {
            guard let childTransform = world.get(Transform.self, from: child.id) else {
                continue
            }

            let newMatrix = parentTransform.matrix * childTransform.matrix
            commands
                .entity(child.id)
                .insert(GlobalTransform(matrix: newMatrix))

            if !child.children.isEmpty {
                updateChildren(child.children, world: world, parentTransform: GlobalTransform(matrix: newMatrix))
            }
        }
    }
}
