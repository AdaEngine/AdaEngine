//
//  Text2DPlugin.swift
//  AdaEngine
//
//  Created by v.prusakov on 3/5/23.
//

/// Append text rendering systems to the scene.
public struct Text2DPlugin: ScenePlugin {
    
    public init() {}
    
    public func setup(in scene: Scene) async {
        scene.addSystem(ExctractTextSystem.self)
        scene.addSystem(Text2DLayoutSystem.self)
    }
}

public struct Text2DRenderPlugin: RenderWorldPlugin {

    public init() {}

    public func setup(in world: RenderWorld) {
        world.addSystem(Text2DRenderSystem.self)
    }
}
