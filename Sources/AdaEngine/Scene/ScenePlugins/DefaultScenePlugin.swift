//
//  DefaultScenePlugin.swift
//  AdaEngine
//
//  Created by v.prusakov on 8/11/22.
//

/// Contains base configuration for any scene in the game.
struct DefaultScenePlugin: ScenePlugin {
    func setup(in scene: Scene) {
        // Add base systems
        scene.addSystem(ScriptComponentUpdateSystem.self)
        
        // Setup render
        scene.addPlugin(VisibilityPlugin())
        scene.addPlugin(CameraPlugin())
        
        scene.addPlugin(SpritePlugin())
        scene.addPlugin(Mesh2DPlugin())
        scene.addPlugin(Text2DPlugin())
        
        // Setup Physics
        scene.addPlugin(Physics2DPlugin())
    }
}

struct DefaultRenderPlugin: ScenePlugin {
    func setup(in scene: Scene) {
        scene.addPlugin(CameraRenderPlugin())
        
        scene.addPlugin(Scene2DPlugin())
        scene.addPlugin(Mesh2DRenderPlugin())
        scene.addPlugin(SpriteRenderPlugin())
        scene.addPlugin(Text2DRenderPlugin())
    }
}
