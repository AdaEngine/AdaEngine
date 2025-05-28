//
//  RegistredComponent.swift
//  AdaEngine
//
//  Created by v.prusakov on 21.05.2025.
//

import AdaECS
@_spi(Runtime) import AdaUtils

// FIXME: We must use Codegen to register components at build time...
/// Sourcery??

enum RegistredComponent: RuntimeRegistrable {
    @MainActor
    static func registerTypes() {
        Transform.registerComponent()
        BoundingComponent.registerComponent()
        Camera.registerComponent()
        ScriptableComponent.registerComponent()
        VisibleEntities.registerComponent()
        Visibility.registerComponent()
        NoFrustumCulling.registerComponent()
        PhysicsBody2DComponent.registerComponent()
        PhysicsJoint2DComponent.registerComponent()
        Collision2DComponent.registerComponent()
        SpriteComponent.registerComponent()
        Circle2DComponent.registerComponent()
        UIComponent.registerComponent()
        TileMapComponent.registerComponent()
        AudioComponent.registerComponent()
        Text2DComponent.registerComponent()
        Mesh2DComponent.registerComponent()
    }
}
