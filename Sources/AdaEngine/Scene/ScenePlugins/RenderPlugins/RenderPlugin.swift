//
//  RenderPlugin.swift
//  
//
//  Created by v.prusakov on 2/19/23.
//

struct RenderPlugin: ScenePlugin {
    func setup(in scene: Scene) {
        scene.addPlugin(Scene2DPlugin())
        scene.addPlugin(CameraPlugin())
    }
}
