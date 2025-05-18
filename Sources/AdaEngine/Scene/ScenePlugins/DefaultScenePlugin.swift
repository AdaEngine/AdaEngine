//
//  DefaultWorldPlugin.swift
//  AdaEngine
//
//  Created by v.prusakov on 8/11/22.
//

/// Contains base configuration for any scene in the game.
/// This plugins will applied for each scene in Ada application and should be passed once per scene.
struct DefaultWorldPlugin: WorldPlugin {
    func setup(in world: World) {
        // Add base systems
        world.addSystem(ScriptComponentUpdateSystem.self)

        // Setup render
        world.addPlugin(VisibilityPlugin())
        world.addPlugin(CameraPlugin())

        world.addPlugin(SpritePlugin())
        world.addPlugin(Mesh2DPlugin())
        world.addPlugin(Text2DPlugin())
        world.addPlugin(AudioPlugin())
        world.addPlugin(UIPlugin())

        // Setup Physics
        world.addPlugin(Physics2DPlugin())
        world.addPlugin(TransformPlugin())
        world.addPlugin(TileMapPlugin())
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
