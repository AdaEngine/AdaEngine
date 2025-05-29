//
//  Text2DPlugin.swift
//  AdaEngine
//
//  Created by v.prusakov on 3/5/23.
//

import AdaApp
import AdaECS
import AdaRender

/// Append text rendering systems to the scene.
public struct Text2DPlugin: Plugin {

    public init() {}
    
    public func setup(in app: AppWorlds) {
        app
//            .addSystem(ExctractTextSystem.self)
            .addSystem(Text2DLayoutSystem.self)
    }
}

public struct Text2DRenderPlugin: Plugin {

    public init() {}

    public func setup(in app: AppWorlds) {
//        world.addSystem(Text2DRenderSystem.self)
    }
}
