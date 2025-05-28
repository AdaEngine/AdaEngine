//
//  Text2DPlugin.swift
//  AdaEngine
//
//  Created by v.prusakov on 3/5/23.
//

import AdaECS
import AdaRender

/// Append text rendering systems to the scene.
public struct Text2DPlugin: WorldPlugin {
    
    public init() {}
    
    public func setup(in world: World) {
        world
//            .addSystem(ExctractTextSystem.self)
            .addSystem(Text2DLayoutSystem.self)
    }
}

public struct Text2DRenderPlugin: RenderWorldPlugin {

    public init() {}

    public func setup(in world: RenderWorld) {
//        world.addSystem(Text2DRenderSystem.self)
    }
}
