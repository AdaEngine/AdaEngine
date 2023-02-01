//
//  DefaultScenePlugin.swift
//  AdaEngine
//
//  Created by v.prusakov on 8/11/22.
//

/// Contains base configuration for any scene in the game.
struct DefaultScenePlugin: ScenePlugin {
    
    init() {}
    
    func setup(in scene: Scene) {
        // Add base systems
        scene.addSystem(ScriptComponentUpdateSystem.self)
        
        // Setup Rendering
        scene.addSystem(CameraSystem.self)
//        scene.addSystem(Render3DSystem.self)
        scene.addSystem(Render2DSystem.self)
        scene.addSystem(ViewContainerSystem.self)
        
        // Setup Physics
        scene.addPlugin(Physics2DPlugin())
    }
}
