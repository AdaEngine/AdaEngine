//
//  SpritePlugin.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/23/23.
//

public struct SpritePlugin: ScenePlugin {
    
    public init() {}
    
    public func setup(in scene: Scene) {
//        scene.addSystem(ExtractSpriteSystem.self)
    }
}

public struct SpriteRenderPlugin: ScenePlugin {
    
    public init() {}
    
    public func setup(in scene: Scene) {
        scene.addSystem(SpriteRenderSystem.self)
        
        let spriteDraw = SpriteDrawPass()
        DrawPassStorage.setDrawPass(spriteDraw)
    }
}
