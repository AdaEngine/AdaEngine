//
//  SpritePlugin.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/23/23.
//

import AdaApp
import AdaRender

/// Plugin for exctracting sprites from scene to RenderWorld.
public struct SpritePlugin: Plugin {

    public init() {}
    
    public func setup(in app: AppWorlds) {
        SpriteComponent.registerComponent()

        guard let renderWorld = app.getSubworldBuilder(by: .renderWorld) else {
            return
        }

        renderWorld
            .addSystem(ExtractSpriteSystem.self)
            .addSystem(SpriteRenderSystem.self)
            .addSystem(ExctractMesh2DSystem.self)
            .insertResource(SpriteDrawPass())
    }
}
