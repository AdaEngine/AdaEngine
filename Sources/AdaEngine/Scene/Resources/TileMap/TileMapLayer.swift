//
//  TileMapLayer.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/5/24.
//

public final class TileMapLayer: Identifiable {

    public var name: String = ""

    public var id: RID = RID()

    public internal(set) weak var tileSet: TileSet?
    public internal(set) weak var tileMap: TileMap?


    var gridSize: Int = 16
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

    public func getSource(at position: PointInt) -> TileSource.ID {
        return self.tileCells[position]?.sourceId ?? .empty
    }

    // MARK: - Internals

    func updateDidFinish() {
        self.needUpdates = false
    }
}
