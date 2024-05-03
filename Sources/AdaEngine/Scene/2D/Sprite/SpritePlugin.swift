//
//  SpritePlugin.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/23/23.
//

/// Plugin for exctracting sprites from scene to RenderWorld.
public struct SpritePlugin: ScenePlugin {
    
    public init() {}
    
    public func setup(in scene: Scene) async {
        scene.addSystem(ExtractSpriteSystem.self)
    }
}

/// Plugin for RenderWorld to render sprites.
public struct SpriteRenderPlugin: ScenePlugin {
    
    public init() {}
    
    public func setup(in scene: Scene) async {
        scene.addSystem(SpriteRenderSystem.self)

        let spriteDraw = SpriteDrawPass()
        DrawPassStorage.setDrawPass(spriteDraw)
    }
}
