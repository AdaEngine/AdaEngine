//
//  TransformSystem.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/5/24.
//

import AdaECS
import Math

@System()
public struct TransformSystem {
    
    @EntityQuery(where: .has(Transform.self))
    private var query
    
    public init(world: World) { }
    
    public func update(context: UpdateContext) {
        self.query.forEach { entity in
            context.taskGroup.addTask { @MainActor in
                if entity.components.isComponentChanged(Transform.self)
                    || !entity.components.has(GlobalTransform.self)
                {
                    let transform = entity.components[Transform.self]!
                    let globalTransform = GlobalTransform(matrix: transform.matrix)
                    entity.components += globalTransform
                }
            }
        }
    }
}

@System(dependencies: [
    .after(TransformSystem.self)
])
public struct ChildTransformSystem {
    
    @Query<Entity, Ref<GlobalTransform>>(filter: [.stored, .added])
    private var query
    
    public init(world: World) { }
    
    public func update(context: UpdateContext) {
        self.query.forEach { entity, transform in
            guard entity.components.isComponentChanged(Transform.self) && !entity.children.isEmpty else {
                return
            }
            
            updateChildren(entity.children, parentTransform: transform.wrappedValue)
        }
    }
    
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
