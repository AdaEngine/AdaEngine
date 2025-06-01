//
//  SpritePlugin.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/23/23.
//

import AdaApp
import AdaECS
import AdaRender

/// Plugin for exctracting sprites from scene to RenderWorld.
public struct SpritePlugin: Plugin {

    public init() {}
    
    public func setup(in app: AppWorlds) {
        SpriteComponent.registerComponent()

        app
            .addSystem(UpdateBoundingsSystem.self, on: .postUpdate)

        guard let renderWorld = app.getSubworldBuilder(by: .renderWorld) else {
            return
        }

        let pipeline = SpriteRenderPipeline()

        renderWorld
            .insertResource(pipeline)
            .insertResource(SpriteDrawPass())
            .addSystem(ExtractSpriteSystem.self)
            .addSystem(SpriteRenderSystem.self)
            .addSystem(ExctractMesh2DSystem.self)
    }
}
