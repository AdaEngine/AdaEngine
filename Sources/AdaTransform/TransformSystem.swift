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
            Added<Transform>,
            Added<GlobalTransform>
        >
    >
    private var query

    @Commands
    private var commands

    public init(world: World) { }
    
    public func update(context: UpdateContext) async {
        self.query.forEach { _, transform, globalTransform in
            globalTransform.wrappedValue = GlobalTransform(matrix: transform.matrix)
        }
    }
}

/// A system that updates the global transform of the children of the entity.
@PlainSystem(dependencies: [
    .after(TransformSystem.self)
])
public struct ChildTransformSystem {
    
    @FilterQuery<Entity, GlobalTransform, RelationshipComponent, Changed<Transform>>
    private var query

    @Commands
    private var commands

    public init(world: World) { }
    
    public func update(context: UpdateContext) async {
        self.query.forEach { _, globalTransform, relationship in
            guard !relationship.children.isEmpty else {
                return
            }

            let children = relationship.children.compactMap(context.world.getEntityByID)
            updateChildren(children, world: context.world, parentTransform: globalTransform)
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

            let grandchildren = child.children
            if !grandchildren.isEmpty {
                updateChildren(grandchildren, world: world, parentTransform: GlobalTransform(matrix: newMatrix))
            }
        }
    }
}
