//
//  DefaultScenePlugin.swift
//  AdaEngine
//
//  Created by v.prusakov on 8/11/22.
//

/// Contains base configuration for any scene in the game.
/// This plugins will applied for each scene in Ada application and should be passed once per scene.
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
        scene.addPlugin(AudioPlugin())
        
        // Setup Physics
        scene.addPlugin(Physics2DPlugin())
    }
}

/// Contains base configurations for render world.
/// This plugins will applied for entire Ada application and should be passed once per run.
struct DefaultRenderPlugin: ScenePlugin {
    func setup(in scene: Scene) {
        scene.addPlugin(CameraRenderPlugin())
        
        scene.addPlugin(Scene2DPlugin())
        scene.addPlugin(Mesh2DRenderPlugin())
        scene.addPlugin(SpriteRenderPlugin())
        scene.addPlugin(Text2DRenderPlugin())
    }
}
