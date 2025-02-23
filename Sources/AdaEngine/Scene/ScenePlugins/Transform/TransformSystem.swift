//
//  TransformSystem.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/5/24.
//

import Math

public struct TransformSystem: System {
    
    public static let dependencies: [SystemDependency] = [
        .after(Physics2DSystem.self)
    ]
    
    static let query = EntityQuery(where: .has(Transform.self))
    
    public init(scene: Scene) { }
    
    public func update(context: UpdateContext) {
        context.scene.performQuery(Self.query).forEach { entity in
            if entity.components.isComponentChanged(Transform.self) || !entity.components.has(GlobalTransform.self) {
                let transform = entity.components[Transform.self]!
                let globalTransform = GlobalTransform(matrix: transform.matrix)
                entity.components += globalTransform
            }
        }
    }
}

public struct ChildTransformSystem: System {
    
    public static let dependencies: [SystemDependency] = [
        .after(TransformSystem.self)
    ]
    
    static let query = EntityQuery(where: .has(Transform.self) && .has(RelationshipComponent.self))
    
    public init(scene: Scene) { }
    
    public func update(context: UpdateContext) {
        context.scene.performQuery(Self.query).forEach { entity in
            guard entity.components.isComponentChanged(Transform.self) && !entity.children.isEmpty else {
                return
            }
            
            let parentTransform = entity.components[GlobalTransform.self]!
            updateChildren(entity.children, parentTransform: parentTransform)
        }
    }
    
    @MainActor
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
