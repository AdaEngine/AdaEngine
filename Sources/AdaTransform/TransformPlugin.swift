//
//  TransformPlugin.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/5/24.
//

import AdaECS

public struct TransformPlugin: WorldPlugin {

    public init() {}

    public func setup(in world: World) {
        world
            .addSystem(TransformSystem.self)
            .addSystem(ChildTransformSystem.self)
    }
}
