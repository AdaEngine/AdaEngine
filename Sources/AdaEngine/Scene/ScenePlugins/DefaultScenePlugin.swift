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
        scene.addPlugin(UIPlugin())

        // Setup Physics
        scene.addPlugin(Physics2DPlugin())
        scene.addPlugin(TransformPlugin())
        scene.addPlugin(TileMapPlugin())
    }
}

/// Contains base configurations for render world.
/// This plugins will applied for entire Ada application and should be passed once per run.
struct DefaultRenderPlugin: RenderWorldPlugin {
    func setup(in world: RenderWorld) async {
        await world.addPlugin(CameraRenderPlugin())
        await world.addPlugin(Scene2DPlugin())
        await world.addPlugin(Mesh2DRenderPlugin())
        await world.addPlugin(SpriteRenderPlugin())
        await world.addPlugin(Text2DRenderPlugin())
    }
}
