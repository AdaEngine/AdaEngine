//
//  SpritePlugin.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/23/23.
//

/// Plugin for exctracting sprites from scene to RenderWorld.
public struct SpritePlugin: WorldPlugin {
    
    public init() {}
    
    public func setup(in world: World) {
        world.addSystem(ExtractSpriteSystem.self)
    }
}

/// Plugin for RenderWorld to render sprites.
public struct SpriteRenderPlugin: RenderWorldPlugin {

    public init() {}

    public func setup(in world: RenderWorld) async {
        world.addSystem(SpriteRenderSystem.self)

        let spriteDraw = SpriteDrawPass()
        DrawPassStorage.setDrawPass(spriteDraw)
    }
}
