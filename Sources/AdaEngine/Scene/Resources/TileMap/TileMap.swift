//
//  TileMap.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/4/24.
//

public class TileMap: Resource {

    public static var resourceType: ResourceType = .text

    public var tileSet: TileSet = TileSet() {
        didSet {
            self.tileSetDidChange()
        }
    }

    @Atomic public internal(set) var layers: [TileMapLayer] = [TileMapLayer()]

    public var resourcePath: String = ""
    public var resourceName: String = ""

    internal private(set) var needsUpdate: Bool = false

    public init() {
        self.tileSetDidChange()
    }

    public required init(asset decoder: AssetDecoder) async throws {
        let fileContent = try decoder.decode(TileMapFileContent.self)
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

    public func encodeContents(with encoder: AssetEncoder) async throws {
        var layers = [TileMapFileContent.Layer]()
        
        for layer in self.layers {
            let tiles = layer.tileCells.elements.map { (position, data) in
                TileMapFileContent.Tile(position: position, atlasPosition: data.atlasCoordinates, sourceId: data.sourceId)
            }
            
            layers.append(
                TileMapFileContent.Layer(name: layer.name, id: layer.id, tiles: tiles)
            )
        }
        
        let content = TileMapFileContent(layers: layers, tileSet: self.tileSet)
        try encoder.encode(content)
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

@_spi(Runtime)
extension TileMap: RuntimeRegistrable {
    public static func registerTypes() {
        TileTextureAtlasSource.registerTileSource()
        TileEntityAtlasSource.registerTileSource()
    }
}

struct TileMapFileContent: Codable {
    
    struct Layer: Codable {
        let name: String
        let id: Int
        let tiles: [Tile]
    }
    
    struct Tile: Codable {
        let position: PointInt
        let atlasPosition: PointInt
        let sourceId: TileSource.ID
    }
    
    let layers: [Layer]
    let tileSet: TileSet
}
