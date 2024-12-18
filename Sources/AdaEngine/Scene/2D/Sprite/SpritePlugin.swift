//
//  SpritePlugin.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/23/23.
//

/// Plugin for exctracting sprites from scene to RenderWorld.
public struct SpritePlugin: ScenePlugin {
    
    public init() {}
    
    public func setup(in scene: Scene) {
        scene.addSystem(ExtractSpriteSystem.self)
    }
}

/// Plugin for RenderWorld to render sprites.
public struct SpriteRenderPlugin: RenderWorldPlugin {

    public init() {}

    public func setup(in world: RenderWorld) async {
        await world.addSystem(SpriteRenderSystem.self)

        let spriteDraw = SpriteDrawPass()
        DrawPassStorage.setDrawPass(spriteDraw)
    }
}
