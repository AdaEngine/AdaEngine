//
//  TileMap.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/4/24.
//

public class TileMap: Asset, @unchecked Sendable {

    public var tileSet: TileSet = TileSet() {
        didSet {
            self.tileSetDidChange()
        }
    }

    public internal(set) var layers: [TileMapLayer] = [TileMapLayer()]
    public nonisolated(unsafe) var assetMetaInfo: AssetMetaInfo?
    internal private(set) var needsUpdate: Bool = false

    public init() {
        self.tileSetDidChange()
    }
    
    public required init(from decoder: AssetDecoder) throws {
        let fileContent = try decoder.decode(FileContent.self)
        self.tileSet = fileContent.tileSet
        
        for layer in fileContent.layers {
            let newLayer = self.createLayer()
            newLayer.name = layer.name
            
            for tile in layer.tiles {
                newLayer.setCell(
                    at: tile.position,
                    sourceId: tile.sourceId,
                    atlasCoordinates: tile.atlasPosition
                )
            }
        }
    }
    
    public func encodeContents(with encoder: AssetEncoder) throws {
        var layers = [FileContent.Layer]()
        
        for layer in self.layers {
            let tiles = layer.tileCells.elements.map { (position, data) in
                FileContent.Tile(
                    position: position,
                    atlasPosition: data.atlasCoordinates,
                    sourceId: data.sourceId
                )
            }
            
            layers.append(
                FileContent.Layer(name: layer.name, id: layer.id, tiles: tiles)
            )
        }
        
        let content = FileContent(layers: layers, tileSet: self.tileSet)
        try encoder.encode(content)
    }
    
    public static func extensions() -> [String] {
        ["tilemap"]
    }

    public func createLayer() -> TileMapLayer {
        let layer = TileMapLayer()
        layer.name = "Layer \(self.layers.count)"
        layer.tileSet = self.tileSet
        layer.tileMap = self
        self.layers.append(layer)
        
        return layer
    }

    public func removeLayer(_ layer: TileMapLayer) {
        guard let index = self.layers.firstIndex(where: { $0 === layer }) else {
            return
        }

        self.layers.remove(at: index)
    }

    public func setCell(for layerIndex: Int, coordinates: PointInt, sourceId: TileSource.ID, atlasCoordinates: PointInt) {
        if !layers.indices.contains(layerIndex) {
            return
        }

        let layer = self.layers[layerIndex]
        layer.setCell(at: coordinates, sourceId: sourceId, atlasCoordinates: atlasCoordinates)
    }

    public func removeCell(for layerIndex: Int, coordinates: PointInt) {
        if !layers.indices.contains(layerIndex) {
            return
        }

        let layer = self.layers[layerIndex]
        layer.removeCell(at: coordinates)
    }

    // MARK: - Internals

    // Update entire tilemap
    func setNeedsUpdate(updateLayers: Bool = false) {
        self.needsUpdate = true

        if updateLayers {
            self.layers.forEach { $0.setNeedsUpdate() }
        }
    }

    func updateDidFinish() {
        self.needsUpdate = false
    }

    // MARK: - Private

    private func tileSetDidChange() {
        self.setNeedsUpdate()

        self.tileSet.tileMap = self

        for layer in layers {
            layer.tileSet = self.tileSet
        }
    }
}

// MARK: - Codable

extension TileMap {
    struct FileContent: Codable {
        
        struct Layer: Codable {
            let name: String
            let id: Int
            let tiles: [Tile]
        }
        
        struct Tile: Codable {
            
            enum CodingKeys: String, CodingKey {
                case position = "p"
                case atlasPosition = "ap"
                case sourceId = "sid"
            }
            
            let position: PointInt
            let atlasPosition: PointInt
            let sourceId: TileSource.ID
            
            init(position: PointInt, atlasPosition: PointInt, sourceId: TileSource.ID) {
                self.position = position
                self.atlasPosition = atlasPosition
                self.sourceId = sourceId
            }
            
            init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                self.position = try PointInt(container.decode([Int].self, forKey: Tile.CodingKeys.position))
                self.atlasPosition = try PointInt(container.decode([Int].self, forKey: Tile.CodingKeys.atlasPosition))
                self.sourceId = try container.decode(TileSource.ID.self, forKey: Tile.CodingKeys.sourceId)
            }
            
            func encode(to encoder: any Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(self.sourceId, forKey: .sourceId)
                try container.encode([position.x, position.y], forKey: .position)
                try container.encode([atlasPosition.x, atlasPosition.y], forKey: .atlasPosition)
            }
        }
        
        let layers: [Layer]
        let tileSet: TileSet
    }

}

@_spi(Runtime)
extension TileMap: RuntimeRegistrable {
    public static func registerTypes() {
        TextureAtlasTileSource.registerTileSource()
        TileEntityAtlasSource.registerTileSource()
    }
}
