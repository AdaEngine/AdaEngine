//
//  ModelSystem.swift
//  AdaEngine
//
//  Created by vladislav.prusakov on 06.12.2024.
//

public struct ModelSystem: System {

    private static var entities = EntityQuery(where: .has(ModelComponent.self) && .has(Transform.self))

    public init(scene: Scene) { }

    public func update(context: UpdateContext) {
        context.scene.performQuery(Self.entities).forEach { entity in
            guard let (modelComponent, transformComponent) = entity[ModelComponent.self, Transform.self] else { return }


        }
    }
}

@Component
struct RenderMeshModelComponent {
    
}
