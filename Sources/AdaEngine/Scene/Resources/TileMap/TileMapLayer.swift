//
//  TileMapLayer.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/5/24.
//

public final class TileMapLayer: Identifiable {

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
    private(set) var tileCells: [PointInt: TileCellData] = [:]

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

        self.needUpdates = true
    }

    public func removeCell(at position: PointInt) {
        self.tileCells[position] = nil

        self.needUpdates = true
    }

    /// - Returns: Return TileSource identifier or ``TileSource.invalidSource``.
    public func getCellTileSource(at position: PointInt) -> TileSource.ID {
        return self.tileCells[position]?.sourceId ?? TileSource.invalidSource
    }

    public func getCellAtlasCoordinates(at position: PointInt) -> PointInt {
        return self.tileCells[position]?.atlasCoordinates ?? PointInt(x: 0, y: 0)
    }

    // MARK: - Internals

    func updateDidFinish() {
        self.needUpdates = false
    }
}
