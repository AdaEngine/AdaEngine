//
//  DefaultWorldPlugin.swift
//  AdaEngine
//
//  Created by v.prusakov on 8/11/22.
//

import AdaECS
import AdaAudio
import AdaTransform

/// Contains base configuration for any scene in the game.
/// This plugins will applied for each scene in Ada application and should be passed once per scene.
public struct DefaultWorldPlugin: WorldPlugin {

    public init() {}

    public func setup(in world: World) {
        world
            .addSystem(ScriptComponentUpdateSystem.self)
            .addPlugin(VisibilityPlugin())
            .addPlugin(CameraPlugin())
            .addPlugin(SpritePlugin())
            .addPlugin(Mesh2DPlugin())
            .addPlugin(Text2DPlugin())
            .addPlugin(ScenePlugin())
            .addPlugin(AudioPlugin())
            .addPlugin(UIPlugin())
            .addPlugin(Physics2DPlugin())
            .addPlugin(TransformPlugin())
            .addPlugin(TileMapPlugin())
    }
}

/// Contains base configurations for render world.
/// This plugins will applied for entire Ada application and should be passed once per run.
public struct DefaultRenderPlugin: RenderWorldPlugin {

    public init() {}
    
    public func setup(in world: RenderWorld) async {
        await world
            .addPlugin(CameraRenderPlugin())
            .addPlugin(Scene2DPlugin())
            .addPlugin(Mesh2DRenderPlugin())
            .addPlugin(SpriteRenderPlugin())
            .addPlugin(Text2DRenderPlugin())
    }
}
