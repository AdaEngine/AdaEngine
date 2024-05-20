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

/// Namespace for LDtk
public enum LDtk { }

extension LDtk {

    public final class TileMap: AdaEngine.TileMap {

        public weak var delegate: LDtk.TileMapDelegate? {
            didSet {
                tileSet.sources.forEach { (_, value) in
                    (value as? LDtk.EntityTileSource)?.delegate = self.delegate
                }
            }
        }

        public private(set) var currentLevelIndex: Int = 0
        public private(set) var levelsCount: Int = 0
        private var project: Project! = nil
        private let filePath: URL

        private let fileWatcher: FileWatcher
        private var fileWatcherObserver: Cancellable?

        public var isHotReloadingEnabled: Bool = true {
            didSet {
                if isHotReloadingEnabled {
                    self.fileWatcherObserver = try! self.fileWatcher.observe(on: .main, block: self.onLDtkFileMapChanged)
                } else {
                    self.fileWatcherObserver = nil
                }
            }
        }

        public required init(asset decoder: AssetDecoder) async throws {
            let pathExt = decoder.assetMeta.filePath.pathExtension

            guard pathExt == "ldtk" || pathExt == "json" else {
                throw AssetDecodingError.invalidAssetExtension("Invalid extension for Ldtk project: \(pathExt)")
            }

            self.fileWatcher = FileWatcher(url: decoder.assetMeta.filePath)
            self.filePath = decoder.assetMeta.filePath

            super.init()

            try await self.loadLdtkProject(from: decoder.assetData)
            self.fileWatcherObserver = try self.fileWatcher.observe(on: .main, block: self.onLDtkFileMapChanged)
        }

        public override func encodeContents(with encoder: AssetEncoder) async throws {
            try await super.encodeContents(with: encoder)
        }

        public func loadLevel(at index: Int) {
            let level = project.levels[index]

            self.currentLevelIndex = index

            for layer in self.layers {
                layer.removeAllCells()
            }

            for layerInstance in level.layerInstances where layerInstance.visible {
                guard let layer = self.layers.first(where: { $0.id == layerInstance.layerDefUid }) else {
                    fatalError("Could not find a layer for id \(layerInstance.layerDefUid)")
                }

                guard let projectLayer = project.defs.layers.first(where: { $0.uid == layerInstance.layerDefUid }) else {
                    fatalError("Could not find a layer in project for id: \(layerInstance.layerDefUid)")
                }

                let source = tileSet.sources[projectLayer.tilesetDefUid] as! TileTextureAtlasSource

                switch layerInstance.__type {
                case .autoLayer, .intGrid:
                    for tile in layerInstance.autoLayerTiles {
                        let atlasCoordinates = Self.gridCoordinates(from: tile.source, gridSize: layerInstance.__gridSize)
                        if !source.hasTile(at: atlasCoordinates) {
                            source.createTile(for: atlasCoordinates)
                        }

                        layer.setCell(
                            at: Self.pixelCoordsToGridCoords(from: tile.position, gridSize: layerInstance.__gridSize),
                            sourceId: projectLayer.tilesetDefUid,
                            atlasCoordinates: atlasCoordinates
                        )
                    }
                case .tiles:
                    for tile in layerInstance.gridTiles {
                        let atlasCoordinates = Self.gridCoordinates(from: tile.source, gridSize: layerInstance.__gridSize)

                        if !source.hasTile(at: atlasCoordinates) {
                            source.createTile(for: atlasCoordinates)
                        }

                        layer.setCell(
                            at: Self.pixelCoordsToGridCoords(from: tile.position, gridSize: layerInstance.__gridSize),
                            sourceId: projectLayer.tilesetDefUid,
                            atlasCoordinates: atlasCoordinates
                        )
                    }
                }
            }
        }

        // MARK: - Private

        private func onLDtkFileMapChanged(_ event: FileWatcher.Event) {
            guard case .update(let data) = event else {
                return
            }

            Task {
                do {
                    try await loadLdtkProject(from: data)
                } catch {
                    print("Failed to update ldtk file", error.localizedDescription)
                }
            }
        }

        @ResourceActor
        private func loadLdtkProject(from data: Data) async throws {
            let jsonDecoder = JSONDecoder()
            let project = try jsonDecoder.decode(Project.self, from: data)

            let tileSet = AdaEngine.TileSet()

            for tileSource in project.defs.tilesets {
                let atlasPath = filePath
                    .deletingLastPathComponent()
                    .appending(path: tileSource.relPath ?? "")

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

            self.layers.removeAll()

            /// Add layers from project to tile map.
            for layer in project.defs.layers {
                let newLayer = self.createLayer()
                newLayer.name = layer.identifier
                newLayer.id = layer.uid
            }

            self.tileSet = tileSet
            self.project = project
            self.levelsCount = project.levels.count

            if levelsCount > 0 {
                self.loadLevel(at: self.currentLevelIndex)
            }
        }

        // MARK: Utils

        private static func pixelCoordsToGridCoords(from coords: [Int], gridSize: Int) -> PointInt {
            return PointInt(x: coords[0] / gridSize, y: gridSize - (coords[1] / gridSize))
        }

        private static func gridCoordinates(from pxCoordinates: [Int], gridSize: Int) -> PointInt {
            let gridX = pxCoordinates[0] / gridSize
            let gridY = pxCoordinates[1] / gridSize

            return PointInt(x: gridX, y: gridY)
        }

        private static func gridCoordinates(from coordinateId: Int, gridWidth: Int) -> PointInt {
            let gridY = coordinateId / gridWidth
            let gridX = coordinateId - (gridY * gridWidth)

            return PointInt(x: gridX, y: gridY)
        }
    }

}

// MARK: - JSON Data

extension LDtk {

    struct Project: Codable {
        let iid: String
        let jsonVersion: Version
        let defs: Definitions
        let levels: [Level]
    }

    struct Definitions: Codable {
        let tilesets: [TileSet]
        let layers: [Layer]
    }

    struct TileSet: Codable {
        let uid: Int
        let identifier: String
        let relPath: String?
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
        let __identifier: String
        let __type: LayerType
        let __gridSize: Int
        let __cWid: Int
        let __cHei: Int
        let iid: String
        let layerDefUid: Int
        let visible: Bool
        let gridTiles: [GridTileData]
        let autoLayerTiles: [GridTileData]
        let entityInstances: [EntityInstance]?
    }

    enum LayerType: String, Codable {
        case autoLayer = "AutoLayer"
        case intGrid = "IntGrid"
        case tiles = "Tiles"
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

    struct Entity: Codable {
        let identifier: String
        let uid: Int
        let width: Int
        let height: Int
        let color: String
        let tilesetId: Int
    }

    public struct EntityInstance: Codable {
        public let identifier: String
        public let iid: String
        public let width: Int
        public let height: Int
        public let defUid: Int
        public let px: [Int]
        public let fieldInstances: [FieldInstance]

        enum CodingKeys: String, CodingKey {
            case identifier = "__identifier"
            case iid, width, height, defUid, px, fieldInstances
        }
    }

    public struct FieldInstance: Codable {
        public let identifier: String
        public let type: String
        public let value: [String]
        public let defUid: Int
        public let readEditorValues: [EditorValue]

        enum CodingKeys: String, CodingKey {
            case identifier = "__identifier"
            case type = "__type"
            case value = "__value"
            case defUid, readEditorValues
        }
    }

    public struct EditorValue: Codable {
        public let id: String
        public let params: [String]
    }
}

extension LDtk {
    public class EntityTileSource: TileEntityAtlasSource {
        weak var delegate: LDtk.TileMapDelegate?
    }

    public protocol TileMapDelegate: AnyObject {
        func tileMap(_ entityTileSource: LDtk.EntityTileSource, entityInstance: LDtk.EntityInstance) -> AdaEngine.Entity
    }
}
