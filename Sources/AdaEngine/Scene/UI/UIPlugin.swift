//
//  UIPlugin.swift
//  AdaEngine
//
//  Created by vladislav.prusakov on 19.08.2024.
//

public struct UIPlugin: WorldPlugin {

    public init() { }

    public func setup(in world: World) {
        world.addSystem(UISystem.self)
    }
}
