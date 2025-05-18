//
//  TransformPlugin.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/5/24.
//

struct TransformPlugin: WorldPlugin {
    func setup(in world: World) {
        world.addSystem(TransformSystem.self)
        world.addSystem(ChildTransformSystem.self)
    }
}
