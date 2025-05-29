//
//  TileMapLayer.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/5/24.
//

import AdaUtils
import OrderedCollections

public class TileMapLayer: Identifiable, @unchecked Sendable {

    public var name: String = ""

    public var id: Int = RID().id

    public internal(set) weak var tileSet: TileSet?
    public internal(set) weak var tileMap: TileMap?

    /// Set z index for layer
    public var zIndex: Int = 0

    struct TileCellData {
        /// Position in atlas
        let atlasCoordinates: PointInt
        /// where get a tile
        let sourceId: TileSource.ID
    }

    /// Key - position of tile in game world
    private(set) var tileCells: OrderedDictionary<PointInt, TileCellData> = [:] {
        didSet {
            self.needUpdates = true
        }
    }

    public var isEnabled: Bool = true {
        didSet {
            self.tileMap?.setNeedsUpdate()
        }
    }

    internal private(set) var needUpdates = false {
        didSet {
            self.tileMap?.setNeedsUpdate()
        }
    }

    public func setCell(at position: PointInt, sourceId: TileSource.ID, atlasCoordinates: PointInt) {
        self.tileCells[position] = TileCellData(
            atlasCoordinates: atlasCoordinates,
            sourceId: sourceId
        )
    }

    public func removeCell(at position: PointInt) {
        self.tileCells[position] = nil
    }

    public func removeAllCells() {
        self.tileCells = [:]
    }

    /// - Returns: Return TileSource identifier or ``TileSource.invalidSource``.
    public func getCellTileSource(at position: PointInt) -> TileSource.ID {
        return self.tileCells[position]?.sourceId ?? TileSource.invalidSource
    }

    public func getCellAtlasCoordinates(at position: PointInt) -> PointInt {
        return self.tileCells[position]?.atlasCoordinates ?? PointInt(x: 0, y: 0)
    }

    // MARK: - Internals

    func setNeedsUpdate() {
        self.needUpdates = true
    }

    func updateDidFinish() {
        self.needUpdates = false
    }
}
