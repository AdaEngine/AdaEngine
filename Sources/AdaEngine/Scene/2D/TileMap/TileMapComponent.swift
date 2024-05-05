//
//  TileMapComponent.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/4/24.
//

@Component
public struct TileMapComponent {

    public var tileMap: TileMap

    /// Contains information about entities
    internal var tileLayers: [TileMapLayer.ID: Entity] = [:]

    public init(tileMap: TileMap) {
        self.tileMap = tileMap
    }
}
