//
//  TransformPlugin.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/5/24.
//

struct TransformPlugin: ScenePlugin {
    func setup(in scene: Scene) {
        scene.addSystem(TransformSystem.self)
        scene.addSystem(ChildTransformSystem.self)
    }
}
