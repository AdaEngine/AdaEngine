//
//  VisibilityPlugin.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/6/23.
//

import AdaECS

/// Visibility Plugin turn on a frustum culling for all entities on the screen.
struct VisibilityPlugin: WorldPlugin {
    func setup(in world: World) {
        world.addSystem(VisibilitySystem.self)
    }
}
