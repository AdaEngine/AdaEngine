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
        app.addSystem(ExtractSpriteSystem.self)
    }
}

/// Plugin for RenderWorld to render sprites.
public struct SpriteRenderPlugin: Plugin {

    public init() {}

    public func setup(in app: AppWorlds) {
        app.addSystem(SpriteRenderSystem.self)

        let spriteDraw = SpriteDrawPass()
        DrawPassStorage.setDrawPass(spriteDraw)
    }
}
