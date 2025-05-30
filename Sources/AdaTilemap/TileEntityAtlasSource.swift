//
//  TileEntityAtlasSource.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/10/24.
//

import AdaUtils
import AdaECS
import Math

public class TileEntityAtlasSource: TileSource, @unchecked Sendable {

    struct EntityTileData {
        var entity: Entity

        var tileData: TileData
    }

    private(set) var tiles: [PointInt: EntityTileData] = [:]
    
    public override init() {
        super.init()
    }
    
    // MARK: - Codable
    
    public required init(from decoder: any Decoder) throws {
        fatalErrorMethodNotImplemented()
    }
    
    public override func encode(to encoder: any Encoder) throws {
        fatalErrorMethodNotImplemented()
    }
    
    // MARK: - Public

    public func createTile(at atlasCoordinates: PointInt, for entity: Entity) {
        let tileData = TileData()
        let data = EntityTileData(entity: entity, tileData: tileData)
        self.tiles[atlasCoordinates] = data
    }

    public func getEntity(at atlasCoordinates: PointInt) -> Entity {
        guard let data = self.tiles[atlasCoordinates] else {
            fatalError("Entity not found at coordinates \(atlasCoordinates)")
        }

        return data.entity
    }

    public func removeTile(at atlasCoordinates: PointInt) {
        self.tiles.removeValue(forKey: atlasCoordinates)
    }

    override func getTileData(at atlasCoordinates: PointInt) -> TileData {
        return self.tiles[atlasCoordinates]?.tileData ?? TileData()
    }
}
