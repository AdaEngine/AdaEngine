//
//  TileMapPlugin.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/4/24.
//

import AdaApp

public struct TileMapPlugin: Plugin {

    public init() {}

    public func setup(in app: AppWorlds) {
        TileMapComponent.registerComponent()
        
        TextureAtlasTileSource.registerTileSource()
        TileEntityAtlasSource.registerTileSource()

        app.addSystem(TileMapSystem.self)
    }
}
