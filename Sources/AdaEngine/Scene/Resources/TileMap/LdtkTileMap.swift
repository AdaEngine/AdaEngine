//
//  LDtkTileMap.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/11/24.
//

// - FIXME: Invalid atlas coordinates
// - FIXME: Entities support

/// Tile map that supports LDtk file formats (`ldtk` or `json`).
/// - Note: We only support tilesets, layers and levels.
///
/// You can load LDtk tile map using ``ResourceManager`` object.
/// ```swift
/// let tileMap = try await ResourceManager.load("@res://Assets/TileMap.ldtk") as LDtkTileMap
/// ```

public final class LDtkTileMap: TileMap {

    private let project: LdtkProject

    // swiftlint:disable:next function_body_length
    public required init(asset decoder: AssetDecoder) async throws {
        let pathExt = decoder.assetMeta.filePath.pathExtension

        guard pathExt == "ldtk" || pathExt == "json" else {
            throw AssetDecodingError.invalidAssetExtension("Invalid extension for Ldtk project: \(pathExt)")
        }

        let jsonDecoder = JSONDecoder()
        let project = try jsonDecoder.decode(LdtkProject.self, from: decoder.assetData)

        let tileSet = TileSet()

        for tileSource in project.defs.tilesets {
            let atlasPath = decoder.assetMeta.filePath
                .deletingLastPathComponent()
                .appending(path: tileSource.relPath)
            
            let image = try await ResourceManager.load(atlasPath.absoluteString) as Image

            let source = TileTextureAtlasSource(
                from: image,
                size: Size(width: Float(tileSource.tileGridSize), height: Float(tileSource.tileGridSize)),
                margin: Size(width: Float(tileSource.padding), height: Float(tileSource.padding))
            )

            source.name = tileSource.identifier
            source.id = tileSource.uid

            tileSet.addTileSource(source)
        }

        self.project = project

        super.init()

        /// Add layers from project to tile map.
        for layer in project.defs.layers {
            let newLayer = self.createLayer()
            newLayer.name = layer.identifier
            newLayer.id = layer.uid
        }

        /// Setup levels using data above.
        for level in project.levels {
            for layerInstance in level.layerInstances where layerInstance.visible {
                guard let layer = self.layers.first(where: { $0.id == layerInstance.layerDefUid }) else {
                    fatalError("Could not find a layer for id \(layerInstance.layerDefUid)")
                }

                guard let projectLayer = project.defs.layers.first(where: { $0.uid == layerInstance.layerDefUid }) else {
                    fatalError("Could not find a layer in project for id: \(layerInstance.layerDefUid)")
                }

                let source = tileSet.sources[projectLayer.tilesetDefUid] as! TileTextureAtlasSource

                for tile in layerInstance.gridTiles {

                    let atlasCoordinates = PointInt(x: tile.source[0] / projectLayer.gridSize, y: tile.source[1] / projectLayer.gridSize)

                    if !source.hasTile(at: atlasCoordinates) {
                        source.createTile(for: atlasCoordinates)
                    }

                    layer.setCell(
                        at: PointInt(x: tile.position[0] / projectLayer.gridSize, y: tile.position[1] / projectLayer.gridSize),
                        sourceId: projectLayer.tilesetDefUid,
                        atlasCoordinates: atlasCoordinates
                    )
                }
            }
        }

        self.tileSet = tileSet
    }

    public override func encodeContents(with encoder: AssetEncoder) async throws {
        try await super.encodeContents(with: encoder)
    }
}

// MARK: - JSON Data

struct LdtkProject: Codable {
    let iid: String
    let jsonVersion: Version
    let defs: Definitions
    let levels: [Level]
}

extension LdtkProject {
    struct Definitions: Codable {
        let tilesets: [TileSet]
        let layers: [Layer]
    }

    struct TileSet: Codable {
        let uid: Int
        let identifier: String
        let relPath: String
        let tileGridSize: Int
        let spacing: Int
        let padding: Int
    }

    struct Level: Codable {
        let identifier: String
        let iid: String
        let layerInstances: [LayerInstance]
    }

    struct LayerInstance: Codable {
        let iid: String
        let layerDefUid: Int
        let visible: Bool
        let gridTiles: [GridTileData]
    }

    struct GridTileData: Codable {

        /// Pixel coordinates of the tile in the layer (array format [x,y]). Don’t forget optional layer offsets, if they exist!
        let position: [Int]

        /// Pixel coordinates of the tile in the tileset ([x,y] format)
        let source: [Int]

        /// “Flip bits”, a 2-bits integer to represent the mirror transformations of the tile.
        /// Bit 0 is X symmetry and bit 1 is Y symmetry.
        /// So you get the following possible values:
        let flipBits: Int

        ///  Alpha/opacity of the tile (0-1, defaults to 1)
        let alpha: Float

        /// The *Tile ID* in the corresponding tileset.
        let tileId: Int

        /// Internal data used by the editor.
        /// - For auto-layer tiles: `[ruleId, coordId]`.
        /// - For tile-layer tiles: `[coordId]`.
        let data: [Int]

        enum CodingKeys: String, CodingKey {
            case position = "px"
            case source = "src"
            case flipBits = "f"
            case alpha = "a"
            case tileId = "t"
            case data = "d"
        }
    }

    struct Layer: Codable {
        let identifier: String
        let uid: Int
        let tilesetDefUid: Int
        let gridSize: Int
    }
}
