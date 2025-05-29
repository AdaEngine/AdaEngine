//
//  DefaultWorldPlugin.swift
//  AdaEngine
//
//  Created by v.prusakov on 8/11/22.
//

import AdaApp
import AdaECS
import AdaAudio
import AdaText
import AdaTransform
import AdaInput
import AdaUI
import AdaPlatform
import AdaScene

/// Contains base configuration for any scene in the game.
/// This plugins will applied for each scene in Ada application and should be passed once per scene.
public struct DefaultPlugins: Plugin {

    public init() {}

    public func setup(in app: AppWorlds) {
        app
            .addPlugin(AppPlatformPlugin())
            .addPlugin(InputPlugin())
            .addPlugin(AssetsPlugin())
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
            .addSystem(ScriptComponentUpdateSystem.self)

        let renderWorld = app.getSubworldBuilder(by: RenderWorld.self)
        renderWorld?.addPlugin(DefaultRenderPlugin())
    }
}

/// Contains base configurations for render world.
/// This plugins will applied for entire Ada application and should be passed once per run.
public struct DefaultRenderPlugin: Plugin {

    public init() {}
    
    public func setup(in app: AppWorlds) {
        app
            .addPlugin(Scene2DPlugin())
            .addPlugin(Mesh2DRenderPlugin())
            .addPlugin(SpriteRenderPlugin())
            .addPlugin(Text2DRenderPlugin())
    }
}
