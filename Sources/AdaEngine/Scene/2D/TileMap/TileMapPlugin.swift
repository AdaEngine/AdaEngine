//
//  TileMapPlugin.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/4/24.
//

public struct TileMapPlugin: WorldPlugin {

    public init() {}

    public func setup(in world: World) {
        world.addSystem(TileMapSystem.self)
    }
}
