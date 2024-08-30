//
//  UIPlugin.swift
//  AdaEngine
//
//  Created by vladislav.prusakov on 19.08.2024.
//

public struct UIPlugin: ScenePlugin {

    public init() { }

    public func setup(in scene: Scene) async {
        scene.addSystem(UISystem.self)
    }
}
