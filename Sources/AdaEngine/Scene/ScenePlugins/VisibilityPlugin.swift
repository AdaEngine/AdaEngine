//
//  VisibilityPlugin.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/6/23.
//

/// Visibility Plugin turn on a frustum culling for all entities on the screen.
struct VisibilityPlugin: ScenePlugin {
    func setup(in scene: Scene) async {
        scene.addSystem(VisibilitySystem.self)
    }
}
