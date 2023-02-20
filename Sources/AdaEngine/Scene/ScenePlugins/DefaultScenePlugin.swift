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
        scene.addPlugin(RenderPlugin())
        scene.addPlugin(VisibilityPlugin())
        
        scene.addPlugin(SpritePlugin())
        
        // Setup Physics
        scene.addPlugin(Physics2DPlugin())
    }
}
