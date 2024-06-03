//
//  TransformSystem.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/5/24.
//

// FIXME: Child transform doesn't works correctly.

public struct TransformSystem: System {

    public static var dependencies: [SystemDependency] = [
        .after(ScriptComponentUpdateSystem.self),
        .before(Physics2DSystem.self)
    ]

    static let query = EntityQuery(where: .has(Transform.self) && .has(RelationshipComponent.self))

    public init(scene: Scene) { }

    public func update(context: UpdateContext) async {
        context.scene.performQuery(Self.query).forEach { entity in
            let transform = entity.components[Transform.self]!

            guard entity.components.isComponentChanged(transform) && !entity.children.isEmpty else {
                return
            }

            for child in entity.children {
                guard let childTransform = child.components[Transform.self] else {
                    continue
                }

                let newMatrix = childTransform.matrix * transform.matrix
                let newTransform = Transform(matrix: newMatrix)
                child.components += newTransform
            }
        }
    }
}
