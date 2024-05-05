//
//  TileMapPlugin.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/4/24.
//

public struct TileMapPlugin: ScenePlugin {

    public init() {}

    public func setup(in scene: Scene) async {
        scene.addSystem(TileMapSystem.self)
    }
}
