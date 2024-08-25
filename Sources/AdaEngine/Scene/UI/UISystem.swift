//
//  UISystem.swift
//  AdaEngine
//
//  Created by vladislav.prusakov on 19.08.2024.
//

public struct UISystem: System {

    private static let query = EntityQuery(where: .has(UIComponent.self) && .has(Transform.self))

    public init(scene: Scene) { }

    public func update(context: UpdateContext) async {
        let entities = context.scene.performQuery(Self.query)
        for entity in entities {
            let (component, transform) = entity.components[UIComponent.self, Transform.self]

        }
    }
}
