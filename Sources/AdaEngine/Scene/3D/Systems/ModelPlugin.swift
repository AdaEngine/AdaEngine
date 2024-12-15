//
//  ModelPlugin.swift
//  AdaEngine
//
//  Created by vladislav.prusakov on 06.12.2024.
//

public struct ModelPlugin: ScenePlugin {
    public func setup(in scene: Scene) {
        scene.addSystem(ModelSystem.self)
    }
}
