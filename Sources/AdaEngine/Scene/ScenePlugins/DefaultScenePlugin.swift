//
//  DefaultScenePlugin.swift
//  AdaEngine
//
//  Created by v.prusakov on 8/11/22.
//

/// Contains base configuration for any scene in the game.
/// This plugins will applied for each scene in Ada application and should be passed once per scene.
struct DefaultScenePlugin: ScenePlugin {
    func setup(in scene: Scene) async {
        // Add base systems
        scene.addSystem(ScriptComponentUpdateSystem.self)

        // Setup render
        await scene.addPlugin(VisibilityPlugin())
        await scene.addPlugin(CameraPlugin())

        await scene.addPlugin(SpritePlugin())
        await scene.addPlugin(Mesh2DPlugin())
        await scene.addPlugin(Text2DPlugin())
        await scene.addPlugin(AudioPlugin())
        await scene.addPlugin(UIPlugin())

        // Setup Physics
        await scene.addPlugin(Physics2DPlugin())

        await scene.addPlugin(TransformPlugin())
        await scene.addPlugin(TileMapPlugin())
    }
}

/// Contains base configurations for render world.
/// This plugins will applied for entire Ada application and should be passed once per run.
struct DefaultRenderPlugin: RenderWorldPlugin {
    func setup(in world: RenderWorld) {
        world.addPlugin(CameraRenderPlugin())
        world.addPlugin(Scene2DPlugin())
        world.addPlugin(Mesh2DRenderPlugin())
        world.addPlugin(SpriteRenderPlugin())
        world.addPlugin(Text2DRenderPlugin())
    }
}
