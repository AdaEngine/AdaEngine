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
        Sprite.registerComponent()

        app
            .addSystem(UpdateBoundingsSystem.self, on: .postUpdate)
            .main
            .registerRequiredComponent(Visibility.self, for: Sprite.self)
            .registerRequiredComponent(BoundingComponent.self, for: Sprite.self)

        guard let renderWorld = app.getSubworldBuilder(by: .renderWorld) else {
            return
        }

        renderWorld
            .insertResource(ExtractedSprites())
            .insertResource(SpriteDrawPass())
            .insertResource(SpriteBatches())
            .initResource(SpriteDrawData.self)
            .initResource(RenderPipelines<SpriteRenderPipeline>.self)
            .addSystem(ExtractSpriteSystem.self, on: .extract)
            .addSystem(PrepareSpritesSystem.self, on: .preUpdate)
            .addSystem(SpriteRenderSystem.self, on: .update)
    }
}
