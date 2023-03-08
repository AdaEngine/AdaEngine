//
//  Text2DPlugin.swift
//  
//
//  Created by v.prusakov on 3/5/23.
//

/// Append text rendering systems to the scene.
public struct Text2DPlugin: ScenePlugin {
    
    public init() {}
    
    public func setup(in scene: Scene) {
        scene.addSystem(Text2DLayoutSystem.self)
        scene.addSystem(Text2DRenderSystem.self)
    }
}
