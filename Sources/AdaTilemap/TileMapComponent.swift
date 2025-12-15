//
//  TileMapComponent.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/4/24.
//

import AdaECS
import Math

/// Component that responsible to display ``TileMap`` instance on screen.
@Component
public struct TileMapComponent {

    /// Contains ``TileMap`` instance that will display on screen.
    public var tileMap: TileMap

    /// The size to use for each tile
    public var tileDisplaySize: Size

    /// Contains information about entities
    ///
    /// Each tile layer contains root entity that holds tile sprite entitis with physic bodies.
    internal var tileLayers: [TileMapLayer.ID: Entity.ID] = [:]

    public init(tileMap: TileMap, tileDisplaySize: Size) {
        self.tileMap = tileMap
        self.tileDisplaySize = tileDisplaySize
    }
}
